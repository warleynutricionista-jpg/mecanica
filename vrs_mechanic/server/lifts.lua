-- ============================================================
-- VRS_MECHANIC - LIFTS SERVER (sistema baseado em mh-carlift)
-- ============================================================

VRS.LiftStates = VRS.LiftStates or {}

local presetFile = Config.Lift.savedPresetFile or 'lift_presets.json'
local savedLiftHeights = {}
local liftOperationCounter = 0

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

local function getVehicleEntityFromNetId(netId)
    return VRS.GetEntityFromNetId and VRS.GetEntityFromNetId(netId, true) or nil
end

local function isVehicleWithinLiftBounds(shopId, liftIndex, vehicle)
    local lift = getLiftEntry(shopId, liftIndex)
    if not lift or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, 'invalid_vehicle', {}
    end

    return VRS.EvaluateLiftVehiclePlacement(
        lift.coords,
        getLiftMetrics(shopId, liftIndex),
        GetEntityCoords(vehicle),
        GetEntityHeading(vehicle),
        nil
    )
end

local function clampHeight(height, shopId, liftIndex)
    local numericHeight = tonumber(height)
    if not numericHeight then return nil end
    local metrics = getLiftMetrics(shopId, liftIndex)
    return VRS.Clamp(numericHeight, metrics.minHeight, metrics.maxHeight)
end

local function getMovementWatchdogDeadline()
    return GetGameTimer() + math.max(tonumber(Config.Lift.MovementTimeoutMs) or 20000, 5000)
end

local function isHybridLiftAuthorityEnabled()
    return VRS.IsExperimentalEnabled and VRS.IsExperimentalEnabled('ServerAuthoritativeLift')
end

local function nextLiftOperationId(shopId, liftIndex)
    liftOperationCounter = liftOperationCounter + 1
    return ('%s:%s:%d:%d'):format(shopId, liftIndex, os.time(), liftOperationCounter)
end

local function assignLiftOperationState(state, source, direction, targetHeight)
    if not isHybridLiftAuthorityEnabled() then
        return state
    end

    state.operationId = nextLiftOperationId(state.shopId, state.liftIndex)
    state.operatorSource = source
    state.operationStartedAt = os.time()
    state.currentState = state.height
    state.targetState = targetHeight or direction
    return state
end

local function clearLiftOperationState(state)
    if not state then return state end
    state.operationId = nil
    state.operatorSource = nil
    state.operationStartedAt = nil
    state.currentState = state.height
    state.targetState = nil
    return state
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
        liftId = (getLiftEntry(shopId, liftIndex) or {}).id,
        liftName = (getLiftEntry(shopId, liftIndex) or {}).liftName,
        height = metrics.minHeight,
        minHeight = metrics.minHeight,
        maxHeight = metrics.maxHeight,
        vehicleNetId = nil,
        plate = nil,
        moving = false,
        direction = nil,
        vehicleAttachment = nil,
    }

    local lift = getLiftEntry(shopId, liftIndex) or {}
    state.liftId = lift.id
    state.liftName = lift.liftName
    state.minHeight = metrics.minHeight
    state.maxHeight = metrics.maxHeight
    state.height = clampHeight(state.height, shopId, liftIndex) or state.minHeight

    -- Validar que o veículo ainda existe
    if state.vehicleNetId and state.vehicleNetId ~= 0 then
        local vehicle = getVehicleEntityFromNetId(state.vehicleNetId)
        if not vehicle then
            state.vehicleNetId = nil
            state.plate = nil
            state.height = state.minHeight
            state.moving = false
            state.direction = nil
            state.vehicleAttachment = nil
            clearLiftOperationState(state)
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
    state.savedHeight = presetKey and clampHeight(savedLiftHeights[presetKey], shopId, liftIndex) or nil
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

    local validVehicle, vehicle, vehicleReason = VRS.ValidateVehicleContext(src, plate, netId, Config.Lift.maxDistance or 12.0)
    if not validVehicle then
        return { success = false, reason = vehicleReason or 'invalid_vehicle' }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    local metrics = getLiftMetrics(shopId, liftIndex)

    if state.moving then
        return { success = false, reason = 'lift_busy' }
    end

    if state.vehicleNetId and state.vehicleNetId ~= netId then
        return { success = false, reason = 'lift_occupied' }
    end

    local existingLiftKey, existingLiftState = VRS.FindLiftByVehicle(plate, netId)
    if existingLiftKey and existingLiftKey ~= key then
        return {
            success = false,
            reason = existingLiftState and existingLiftState.vehicleNetId and 'vehicle_already_on_other_lift' or 'lift_occupied'
        }
    end

    local placementOk, placementReason, placement = isVehicleWithinLiftBounds(shopId, liftIndex, vehicle)
    if not placementOk then
        VRS.LiftDebugLog('attach', ('Vínculo negado para %s: reason=%s fwd=%.2f lat=%.2f heading=%.2f'):format(
            key,
            tostring(placementReason),
            placement and placement.forwardOffset or -1.0,
            placement and placement.lateralOffset or -1.0,
            placement and placement.headingDelta or -1.0
        ))
        return { success = false, reason = placementReason or 'misaligned_vehicle' }
    end

    state.vehicleNetId = netId
    state.plate = plate
    state.height = metrics.minHeight
    state.minHeight = metrics.minHeight
    state.maxHeight = metrics.maxHeight
    state.moving = false
    state.direction = nil
    state.vehicleAttachment = {
        forwardOffset = placement and placement.forwardOffset or 0.0,
        lateralOffset = placement and placement.lateralOffset or 0.0,
        verticalOffset = metrics.vehicleOffset and metrics.vehicleOffset.z or (Config.Lift.VehicleZOffset or 0.36),
        headingOffset = placement and placement.headingOffset or 0.0,
    }
    clearLiftOperationState(state)
    VRS.LiftStates[key] = state

    if vehicle then
        Entity(vehicle).state:set('vrs:onLift', { shopId = shopId, liftIndex = liftIndex, plate = plate }, true)
    end

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
    local metrics = getLiftMetrics(shopId, liftIndex)

    if state.moving then
        return { success = false, reason = 'lift_busy' }
    end

    if not state.vehicleNetId then
        return { success = false, reason = 'lift_empty' }
    end

    local tolerance = 0.05
    if (state.height or 0.0) > (metrics.minHeight + tolerance) then
        return { success = false, reason = 'lift_not_lowered' }
    end

    local vehicle = getVehicleEntityFromNetId(state.vehicleNetId)
    if vehicle then
        Entity(vehicle).state:set('vrs:onLift', nil, true)
    end

    VRS.LiftStates[key] = {
        shopId = shopId,
        liftIndex = liftIndex,
        height = metrics.minHeight,
        minHeight = metrics.minHeight,
        maxHeight = metrics.maxHeight,
        vehicleNetId = nil,
        plate = nil,
        moving = false,
        direction = nil,
        vehicleAttachment = nil,
    }
    clearLiftOperationState(VRS.LiftStates[key])

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
    local metrics = getLiftMetrics(shopId, liftIndex)

    if isHybridLiftAuthorityEnabled() then
        VRS.DebugLog('liftAuthority', ('Comando %s solicitado para %s por source %s.'):format(command, key, source))
    end

    if command == 'stop' then
        state.moving = false
        state.direction = nil
        state.targetHeight = nil
        clearLiftOperationState(state)
        VRS.LiftStates[key] = state
        syncLiftState(shopId, liftIndex)
        broadcastMovement(shopId, liftIndex, 'stop')
        return { success = true, operationId = state.operationId }
    end

    -- Validar up/down
    if command == 'up' then
        if Config.Lift.requireVehicleToRaise and not state.vehicleNetId then
            if isHybridLiftAuthorityEnabled() then
                VRS.DebugLog('liftAuthority', ('Subida negada para %s: elevador vazio.'):format(key))
            end
            return { success = false, reason = 'lift_empty' }
        end
        if (state.height or 0.0) >= metrics.maxHeight - 0.01 then
            return { success = false, reason = 'already_top' }
        end
    elseif command == 'down' then
        if (state.height or 0.0) <= metrics.minHeight + 0.01 then
            return { success = false, reason = 'already_bottom' }
        end
    end

    state.moving = true
    state.direction = command
    assignLiftOperationState(state, source, command, command)
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, command)

    return {
        success = true,
        operationId = state.operationId,
        operatorSource = state.operatorSource,
        operationStartedAt = state.operationStartedAt,
    }
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
    if isHybridLiftAuthorityEnabled() then
        VRS.DebugLog('liftAuthority', ('Preset solicitado para %s por source %s.'):format(key, source))
    end

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
    state.minHeight = getLiftMetrics(shopId, liftIndex).minHeight
    state.maxHeight = getLiftMetrics(shopId, liftIndex).maxHeight
    assignLiftOperationState(state, source, direction, clamped)
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, direction)

    -- Monitorar até atingir altura alvo
    CreateThread(function()
        local deadline = getMovementWatchdogDeadline()
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
                clearLiftOperationState(currentState)
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                break
            end

            if GetGameTimer() >= deadline then
                currentState.height = clampHeight(currentState.height, shopId, liftIndex) or currentState.minHeight or 0.0
                currentState.moving = false
                currentState.direction = nil
                currentState.targetHeight = nil
                clearLiftOperationState(currentState)
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                VRS.DebugLog('liftSync', ('Timeout de movimento ao ajustar altura do elevador %s/%s.'):format(shopId, liftIndex))
                break
            end
        end
    end)

    return {
        success = true,
        operationId = state.operationId,
        operatorSource = state.operatorSource,
        operationStartedAt = state.operationStartedAt,
    }
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
    assignLiftOperationState(state, source, direction, clamped)
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    broadcastMovement(shopId, liftIndex, direction)

    CreateThread(function()
        local deadline = getMovementWatchdogDeadline()
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
                clearLiftOperationState(currentState)
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                break
            end

            if GetGameTimer() >= deadline then
                currentState.height = clampHeight(currentState.height, shopId, liftIndex) or currentState.minHeight or 0.0
                currentState.moving = false
                currentState.direction = nil
                currentState.targetHeight = nil
                clearLiftOperationState(currentState)
                VRS.LiftStates[key] = currentState
                syncLiftState(shopId, liftIndex)
                broadcastMovement(shopId, liftIndex, 'stop')
                VRS.DebugLog('liftSync', ('Timeout ao mover elevador salvo %s/%s.'):format(shopId, liftIndex))
                break
            end
        end
    end)

    return {
        success = true,
        operationId = state.operationId,
        operatorSource = state.operatorSource,
        operationStartedAt = state.operationStartedAt,
    }
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

RegisterNetEvent('vrs_mechanic:server:syncLiftHeight', function(shopId, liftIndex, height, operationId)
    local src = source
    local ok = validateLiftAccess(src, shopId, liftIndex)
    if not ok then return end

    local key = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftStates[key]
    if not state or not state.moving then return end

    if isHybridLiftAuthorityEnabled() then
        if state.operatorSource and state.operatorSource ~= src then
            VRS.DebugLog('liftAuthority', ('Sync negado para %s por source %s; owner=%s'):format(key, src, state.operatorSource))
            return
        end
        if state.operationId and operationId and state.operationId ~= operationId then
            VRS.DebugLog('liftAuthority', ('Sync negado para %s por operationId divergente.'):format(key))
            return
        end
    end

    local clampedHeight = clampHeight(height, shopId, liftIndex)
    if clampedHeight == nil then return end

    state.height = roundHeight(clampedHeight)
    state.currentState = state.height
    state.minHeight = state.minHeight or getLiftMetrics(shopId, liftIndex).minHeight
    state.maxHeight = state.maxHeight or getLiftMetrics(shopId, liftIndex).maxHeight
    VRS.LiftStates[key] = state
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
