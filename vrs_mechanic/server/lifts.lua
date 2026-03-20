-- ============================================================
-- VRS_MECHANIC - LIFTS SERVER (sistema baseado em mh-carlift)
-- ============================================================

VRS.LiftStates = VRS.LiftStates or {}

local presetFile = Config.Lift.savedPresetFile or 'lift_presets.json'
local savedLiftHeights = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function roundHeight(value)
    return tonumber(('%0.3f'):format(value or 0.0)) or 0.0
end

local function getLiftEntry(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    return shop and shop.lifts and shop.lifts[liftIndex] or nil
end

local function getLiftMetrics(shopId, liftIndex)
    return VRS.GetLiftMetrics(getLiftEntry(shopId, liftIndex) or {})
end

local function clampHeight(height, shopId, liftIndex)
    local numericHeight = tonumber(height)
    if not numericHeight then return nil end
    local metrics = getLiftMetrics(shopId, liftIndex)
    return VRS.Clamp(numericHeight, metrics.minHeight, metrics.maxHeight)
end

local function getPresetKey(source, shopId, liftIndex)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    return ('%s:%s:%s'):format(player.PlayerData.citizenid, shopId, liftIndex)
end

-- ============================================================
-- PERSISTÊNCIA DE ALTURAS SALVAS
-- ============================================================

local function loadSavedHeights()
    local resourceName = GetCurrentResourceName()
    local raw = LoadResourceFile(resourceName, presetFile)
    if not raw or raw == '' then
        savedLiftHeights = {}
        return
    end
    local decoded = json.decode(raw)
    savedLiftHeights = type(decoded) == 'table' and decoded or {}
end

local function persistSavedHeights()
    SaveResourceFile(GetCurrentResourceName(), presetFile, json.encode(savedLiftHeights), -1)
end

-- ============================================================
-- ESTADO DO ELEVADOR
-- ============================================================

local function buildLiftState(shopId, liftIndex)
    local key = getLiftKey(shopId, liftIndex)
    local metrics = getLiftMetrics(shopId, liftIndex)
    local state = VRS.LiftStates[key] or {
        shopId = shopId,
        liftIndex = liftIndex,
        height = metrics.minHeight,
        minHeight = metrics.minHeight,
        maxHeight = metrics.maxHeight,
        vehicleNetId = nil,
        plate = nil,
        moving = false,
        direction = nil,
    }

    state.minHeight = metrics.minHeight
    state.maxHeight = metrics.maxHeight
    state.height = clampHeight(state.height, shopId, liftIndex) or state.minHeight

    -- Validar que o veículo ainda existe
    if state.vehicleNetId and state.vehicleNetId ~= 0 then
        local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            state.vehicleNetId = nil
            state.plate = nil
            state.height = state.minHeight
            state.moving = false
            state.direction = nil
        end
    end

    return state
end

local function syncLiftState(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    VRS.LiftStates[getLiftKey(shopId, liftIndex)] = state
    TriggerClientEvent('vrs_mechanic:client:syncLiftState', -1, shopId, liftIndex, state)
    return state
end

local function broadcastMovement(shopId, liftIndex, direction)
    TriggerClientEvent('vrs_mechanic:client:liftMovement', -1, shopId, liftIndex, direction or 'stop')
end

-- ============================================================
-- VALIDAÇÃO DE ACESSO
-- ============================================================

local function validateLiftAccess(source, shopId, liftIndex)
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts or not shop.lifts[liftIndex] then
        return false, 'invalid_lift'
    end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(source, shopId) then
            return false, 'no_access'
        end
        if Config.Lift.requireDuty and not VRS.IsOnDuty(source) then
            return false, 'not_on_duty'
        end
    end

    return true, nil, shop
end

-- ============================================================
-- CALLBACKS: ESTADO
-- ============================================================

lib.callback.register('vrs_mechanic:server:getLiftState', function(source, shopId, liftIndex)
    local ok = validateLiftAccess(source, shopId, liftIndex)
    if not ok then return nil end

    local state = syncLiftState(shopId, liftIndex)
    local presetKey = getPresetKey(source, shopId, liftIndex)
    state.savedHeight = presetKey and savedLiftHeights[presetKey] or nil
    return state
end)

-- ============================================================
-- CALLBACKS: COLOCAR/RETIRAR VEÍCULO
-- ============================================================

lib.callback.register('vrs_mechanic:server:placeVehicleOnLift', function(source, shopId, liftIndex, netId, plate)
    local src = source
    local ok, reason = validateLiftAccess(src, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local validVehicle, _, vehicleReason = VRS.ValidateVehicleContext(src, plate, netId, Config.Lift.maxDistance or 12.0)
    if not validVehicle then
        return { success = false, reason = vehicleReason or 'invalid_vehicle' }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)

    if state.moving then
        return { success = false, reason = 'lift_busy' }
    end

    if state.vehicleNetId and state.vehicleNetId ~= netId then
        return { success = false, reason = 'lift_occupied' }
    end

    state.vehicleNetId = netId
    state.plate = plate
    state.height = getLiftMetrics(shopId, liftIndex).minHeight
    state.moving = false
    state.direction = nil
    VRS.LiftStates[key] = state

    local synced = syncLiftState(shopId, liftIndex)
    return { success = true, state = synced, message = 'Veículo posicionado e pronto para serviço.' }
end)

lib.callback.register('vrs_mechanic:server:removeVehicleFromLift', function(source, shopId, liftIndex)
    local src = source
    local ok, reason = validateLiftAccess(src, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)

    if state.moving then
        return { success = false, reason = 'lift_busy' }
    end

    if not state.vehicleNetId then
        return { success = false, reason = 'lift_empty' }
    end

    local tolerance = 0.05
    if (state.height or 0.0) > ((getLiftMetrics(shopId, liftIndex).minHeight) + tolerance) then
        return { success = false, reason = 'lift_not_lowered' }
    end

    VRS.LiftStates[key] = {
        shopId = shopId,
        liftIndex = liftIndex,
        height = getLiftMetrics(shopId, liftIndex).minHeight,
        minHeight = getLiftMetrics(shopId, liftIndex).minHeight,
        maxHeight = getLiftMetrics(shopId, liftIndex).maxHeight,
        vehicleNetId = nil,
        plate = nil,
        moving = false,
        direction = nil,
    }

    syncLiftState(shopId, liftIndex)
    return { success = true }
end)

-- ============================================================
-- CALLBACKS: CONTROLE DE MOVIMENTO
-- ============================================================

lib.callback.register('vrs_mechanic:server:liftCommand', function(source, shopId, liftIndex, command)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)

    if command == 'stop' then
        state.moving = false
        state.direction = nil
        VRS.LiftStates[key] = state
        syncLiftState(shopId, liftIndex)
        broadcastMovement(shopId, liftIndex, 'stop')
        return { success = true }
    end

    -- Validar up/down
    if command == 'up' then
        if Config.Lift.requireVehicleToRaise and not state.vehicleNetId then
            return { success = false, reason = 'lift_empty' }
        end
        if (state.height or 0.0) >= (getLiftMetrics(shopId, liftIndex).maxHeight) - 0.01 then
            return { success = false, reason = 'already_top' }
        end
    elseif command == 'down' then
        if (state.height or 0.0) <= (getLiftMetrics(shopId, liftIndex).minHeight) + 0.01 then
            return { success = false, reason = 'already_bottom' }
        end
    end

    state.moving = true
    state.direction = command
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, command)

    return { success = true }
end)

-- ============================================================
-- CALLBACKS: ALTURA PREDEFINIDA
-- ============================================================

lib.callback.register('vrs_mechanic:server:setLiftHeight', function(source, shopId, liftIndex, targetHeight)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)

    if state.moving then
        return { success = false, reason = 'lift_busy' }
    end

    local clamped = clampHeight(targetHeight, shopId, liftIndex)
    if clamped == nil then
        return { success = false, reason = 'invalid_height' }
    end

    if clamped > (getLiftMetrics(shopId, liftIndex).minHeight) + 0.01 and not state.vehicleNetId and Config.Lift.requireVehicleToRaise then
        return { success = false, reason = 'lift_empty' }
    end

    local currentHeight = state.height or 0.0
    if math.abs(clamped - currentHeight) <= 0.02 then
        return { success = false, reason = 'same_height' }
    end

    -- Determinar direção e iniciar movimento contínuo até o alvo
    local direction = clamped > currentHeight and 'up' or 'down'
    state.moving = true
    state.direction = direction
    state.targetHeight = clamped
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, direction)

    -- Monitorar até atingir altura alvo
    CreateThread(function()
        while true do
            Wait(100)
            local currentState = VRS.LiftStates[key]
            if not currentState or not currentState.moving then break end
            if not currentState.targetHeight then break end

            -- Verificar se atingiu o alvo (clientes atualizam height)
            local h = currentState.height or 0.0
            if math.abs(h - clamped) <= 0.03 or
               (direction == 'up' and h >= clamped) or
               (direction == 'down' and h <= clamped) then
                currentState.height = clamped
                currentState.moving = false
                currentState.direction = nil
                currentState.targetHeight = nil
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                break
            end
        end
    end)

    return { success = true }
end)

-- ============================================================
-- CALLBACKS: SALVAR/CARREGAR ALTURAS
-- ============================================================

lib.callback.register('vrs_mechanic:server:saveLiftHeight', function(source, shopId, liftIndex)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then return { success = false, reason = reason } end

    local state = buildLiftState(shopId, liftIndex)
    local presetKey = getPresetKey(source, shopId, liftIndex)
    if not presetKey then return { success = false, reason = 'no_access' } end

    savedLiftHeights[presetKey] = clampHeight(state.height, shopId, liftIndex) or getLiftMetrics(shopId, liftIndex).minHeight
    persistSavedHeights()

    return {
        success = true,
        savedHeight = savedLiftHeights[presetKey],
        message = 'Altura salva com sucesso.',
    }
end)

lib.callback.register('vrs_mechanic:server:goToSavedLiftHeight', function(source, shopId, liftIndex)
    local presetKey = getPresetKey(source, shopId, liftIndex)
    if not presetKey or savedLiftHeights[presetKey] == nil then
        return { success = false, reason = 'no_saved_height' }
    end

    -- Reutilizar lógica de setLiftHeight diretamente
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then return { success = false, reason = reason } end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if state.moving then return { success = false, reason = 'lift_busy' } end

    local targetHeight = savedLiftHeights[presetKey]
    local clamped = clampHeight(targetHeight, shopId, liftIndex)
    if clamped == nil then return { success = false, reason = 'invalid_height' } end
    if clamped > (getLiftMetrics(shopId, liftIndex).minHeight) + 0.01 and not state.vehicleNetId and Config.Lift.requireVehicleToRaise then
        return { success = false, reason = 'lift_empty' }
    end

    local currentHeight = state.height or 0.0
    if math.abs(clamped - currentHeight) <= 0.02 then
        return { success = false, reason = 'same_height' }
    end

    local direction = clamped > currentHeight and 'up' or 'down'
    state.moving = true
    state.direction = direction
    state.targetHeight = clamped
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, direction)

    CreateThread(function()
        while true do
            Wait(100)
            local currentState = VRS.LiftStates[key]
            if not currentState or not currentState.moving then break end
            if not currentState.targetHeight then break end
            local h = currentState.height or 0.0
            if math.abs(h - clamped) <= 0.03 or
               (direction == 'up' and h >= clamped) or
               (direction == 'down' and h <= clamped) then
                currentState.height = clamped
                currentState.moving = false
                currentState.direction = nil
                currentState.targetHeight = nil
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                break
            end
        end
    end)

    return { success = true }
end)

-- ============================================================
-- BUSCA DE VEÍCULO EM ELEVADOR
-- ============================================================

function VRS.FindLiftByVehicle(plate, netId)
    for key, state in pairs(VRS.LiftStates or {}) do
        if state and state.vehicleNetId and
           ((netId and state.vehicleNetId == netId) or (plate and state.plate == plate)) then
            return key, state
        end
    end
    return nil, nil
end

-- ============================================================
-- SYNC DE ALTURA DO CLIENT
-- ============================================================

RegisterNetEvent('vrs_mechanic:server:syncLiftHeight', function(shopId, liftIndex, height)
    local key = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftStates[key]
    if state then
        state.height = roundHeight(height)
        VRS.LiftStates[key] = state
    end
end)

-- ============================================================
-- INICIALIZAÇÃO
-- ============================================================

CreateThread(loadSavedHeights)


if not VRS.LiftAdminAvailable then
    lib.callback.register('vrs_mechanic:server:getLiftLayouts', function(source)
        local layouts = {}
        local shops = {}

        for shopId, shop in pairs(Config.Shops) do
            layouts[shopId] = {}
            for index, lift in ipairs(shop.lifts or {}) do
                layouts[shopId][#layouts[shopId] + 1] = {
                    id = lift.id or ('%s_static_%d'):format(shopId, index),
                    model = lift.model or Config.Lift.DefaultModelName or 'standard_lift',
                    ownerJob = lift.ownerJob or shop.job,
                    shopId = shopId,
                    category = lift.category or shopId,
                    source = lift.source or 'static',
                    staticIndex = lift.staticIndex or index,
                    length = lift.length,
                    width = lift.width,
                    minHeight = lift.minHeight,
                    maxHeight = lift.maxHeight,
                    sourceType = lift.sourceType,
                    useExistingEntity = lift.useExistingEntity,
                    platformOffset = lift.platformOffset and { x = lift.platformOffset.x, y = lift.platformOffset.y, z = lift.platformOffset.z } or nil,
                    vehicleOffset = lift.vehicleOffset and { x = lift.vehicleOffset.x, y = lift.vehicleOffset.y, z = lift.vehicleOffset.z } or nil,
                    interactionOffset = lift.interactionOffset and { x = lift.interactionOffset.x, y = lift.interactionOffset.y, z = lift.interactionOffset.z } or nil,
                    controlPanel = lift.controlPanel and {
                        x = lift.controlPanel.x,
                        y = lift.controlPanel.y,
                        z = lift.controlPanel.z,
                        w = lift.controlPanel.w,
                    } or nil,
                    coords = {
                        x = lift.coords.x,
                        y = lift.coords.y,
                        z = lift.coords.z,
                        w = lift.coords.w,
                    },
                    metadata = lift.metadata or {},
                }
            end

            if VRS.CanManageLifts and VRS.CanManageLifts(source, shopId) then
                shops[#shops + 1] = {
                    shopId = shopId,
                    label = shop.label,
                    job = shop.job,
                    type = shop.type,
                    liftCount = #(shop.lifts or {}),
                }
            end
        end

        return { layouts = layouts, shops = shops, allowed = #shops > 0 }
    end)

    lib.callback.register('vrs_mechanic:server:saveLiftLayout', function()
        return { success = false, reason = 'admin_unavailable' }
    end)

    lib.callback.register('vrs_mechanic:server:deleteLiftLayout', function()
        return { success = false, reason = 'admin_unavailable' }
    end)
end
