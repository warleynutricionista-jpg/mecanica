-- ============================================================
-- VRS_MECHANIC - SISTEMA DE ELEVADOR (baseado em mh-carlift)
-- Mecânica de props físicos com controle server-authoritative
-- ============================================================

local spawnedLifts = {}      -- { [liftKey] = { platform, poles, elecbox } }
local liftMovement = {}      -- { [liftKey] = 'up' | 'down' | nil }
local attachedVehicles = {}  -- { [liftKey] = vehicleEntity }

-- ============================================================
-- HELPERS
-- ============================================================

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function roundHeight(value)
    return tonumber(('%0.3f'):format(value or 0.0)) or 0.0
end

local function prepareModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    return hash
end

local function createProp(model, x, y, z, heading)
    local hash = prepareModel(model)
    if not IsModelValid(hash) then return nil end
    local obj = CreateObject(hash, x, y, z, false, false, false)
    if obj and obj ~= 0 then
        SetEntityAsMissionEntity(obj, true, true)
        SetEntityCollision(obj, true, true)
        FreezeEntityPosition(obj, true)
        SetEntityHeading(obj, heading or 0.0)
    end
    return obj
end

local function requestControl(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function fetchLiftLayoutsSafe()
    local ok, response = pcall(function()
        return lib.callback.await('vrs_mechanic:server:getLiftLayouts', false)
    end)

    if not ok then
        print(('[vrs_mechanic] Lift admin callback indisponível no client: %s'):format(response))
        return nil
    end

    return response
end

-- ============================================================
-- SPAWN DE PROPS DO ELEVADOR
-- ============================================================

local function spawnPoles(platformEntity, heading)
    local poles = {}
    local poleModel = Config.Lift.PoleModel
    local poleZ = Config.Lift.PoleZOffset or -0.30
    local offsets = {
        vec3(1.43, -2.88, poleZ),
        vec3(-1.43, -2.88, poleZ),
        vec3(-1.43, 2.88, poleZ),
        vec3(1.43, 2.88, poleZ),
    }

    for i, offset in ipairs(offsets) do
        local worldCoords = GetOffsetFromEntityInWorldCoords(platformEntity, offset.x, offset.y, offset.z)
        local poleHeading = (i == 1 or i == 4) and (heading - 180.0) or heading
        local pole = createProp(poleModel, worldCoords.x, worldCoords.y, worldCoords.z, poleHeading)
        if pole then
            poles[#poles + 1] = pole
        end
    end

    return poles
end

local function spawnElecBox(platformEntity, heading)
    local offset = Config.Lift.ElecBoxOffset or vec3(0.0, -3.3, -0.7)
    local worldCoords = GetOffsetFromEntityInWorldCoords(platformEntity, offset.x, offset.y, offset.z)
    return createProp(Config.Lift.ElecBoxModel, worldCoords.x, worldCoords.y, worldCoords.z, heading)
end

local function spawnLiftProps(shopId, liftIndex)
    local liftKey = getLiftKey(shopId, liftIndex)
    if spawnedLifts[liftKey] then return spawnedLifts[liftKey] end

    local shop = Config.Shops[shopId]
    local lift = shop and shop.lifts and shop.lifts[liftIndex]
    if not lift then return nil end

    local x, y, z = lift.coords.x, lift.coords.y, lift.coords.z
    local heading = lift.coords.w or 0.0

    local platform = createProp(Config.Lift.PlatformModel, x, y, z, heading)
    if not platform or platform == 0 then return nil end

    local poles = {}
    local elecbox = nil

    if Config.Lift.SpawnPoles then
        poles = spawnPoles(platform, heading)
    end

    if Config.Lift.SpawnElecBox then
        elecbox = spawnElecBox(platform, heading)
    end

    spawnedLifts[liftKey] = {
        platform = platform,
        poles = poles,
        elecbox = elecbox,
        baseZ = z,
        heading = heading,
        baseCoords = vec3(x, y, z),
    }

    return spawnedLifts[liftKey]
end

local function destroyLiftProps(liftKey)
    local data = spawnedLifts[liftKey]
    if not data then return end

    if data.platform and DoesEntityExist(data.platform) then
        DeleteEntity(data.platform)
    end

    for _, pole in ipairs(data.poles or {}) do
        if pole and DoesEntityExist(pole) then
            DeleteEntity(pole)
        end
    end

    if data.elecbox and DoesEntityExist(data.elecbox) then
        DeleteEntity(data.elecbox)
    end

    spawnedLifts[liftKey] = nil
end

local function destroyAllLiftProps()
    for liftKey in pairs(spawnedLifts) do
        destroyLiftProps(liftKey)
    end
end

local function spawnAllLiftProps()
    for shopId, shop in pairs(Config.Shops) do
        if shop.lifts then
            for liftIndex in ipairs(shop.lifts) do
                spawnLiftProps(shopId, liftIndex)
            end
        end
    end
end

function VRS.RebuildLiftProps(refreshStates)
    local validKeys = {}
    for shopId, shop in pairs(Config.Shops) do
        for liftIndex in ipairs(shop.lifts or {}) do
            validKeys[getLiftKey(shopId, liftIndex)] = true
        end
    end

    for liftKey in pairs(VRS.LiftState or {}) do
        if not validKeys[liftKey] then
            VRS.LiftState[liftKey] = nil
            VRS.OnLift[liftKey] = nil
            attachedVehicles[liftKey] = nil
            liftMovement[liftKey] = nil
        end
    end

    destroyAllLiftProps()
    spawnAllLiftProps()

    if refreshStates then
        CreateThread(function()
            Wait(200)
            for shopId, shop in pairs(Config.Shops) do
                if shop.lifts then
                    for liftIndex in ipairs(shop.lifts) do
                        VRS.RefreshLiftState(shopId, liftIndex)
                    end
                end
            end
        end)
    end
end

function VRS.ApplyLiftLayouts(layouts)
    if type(layouts) ~= 'table' then return end

    for shopId, lifts in pairs(layouts) do
        if Config.Shops[shopId] then
            Config.Shops[shopId].lifts = lifts or {}
        end
    end

    if VRS.RebuildLiftTargets then
        VRS.RebuildLiftTargets()
    end

    VRS.RebuildLiftProps(true)
end

-- ============================================================
-- FUNÇÕES DE PLATAFORMA
-- ============================================================

local function getPlatformCurrentHeight(liftKey)
    local data = spawnedLifts[liftKey]
    if not data or not data.platform or not DoesEntityExist(data.platform) then return 0.0 end
    local currentZ = GetEntityCoords(data.platform).z
    return roundHeight(currentZ - data.baseZ)
end

local function setPlatformHeight(liftKey, height)
    local data = spawnedLifts[liftKey]
    if not data or not data.platform or not DoesEntityExist(data.platform) then return end

    local targetZ = data.baseZ + height
    FreezeEntityPosition(data.platform, false)
    SetEntityCoordsNoOffset(data.platform, data.baseCoords.x, data.baseCoords.y, targetZ, false, false, false)
    FreezeEntityPosition(data.platform, true)
end

local function updateVehicleOnLift(liftKey, height)
    local vehicle = attachedVehicles[liftKey]
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local data = spawnedLifts[liftKey]
    if not data then return end

    local vehicleZ = data.baseZ + height + (Config.Lift.VehicleZOffset or 0.36)
    requestControl(vehicle)
    SetEntityCoordsNoOffset(vehicle, data.baseCoords.x, data.baseCoords.y, vehicleZ, false, false, false)
    SetEntityHeading(vehicle, data.heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)
end

-- ============================================================
-- FUNÇÕES PÚBLICAS VRS
-- ============================================================

function VRS.GetLiftKey(shopId, liftIndex)
    return getLiftKey(shopId, liftIndex)
end

function VRS.GetLiftBaseCoords(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    local lift = shop and shop.lifts and shop.lifts[liftIndex]
    if not lift then return nil end
    return vec3(lift.coords.x, lift.coords.y, lift.coords.z), lift.coords.w or 0.0
end

function VRS.GetLiftWorldCoords(shopId, liftIndex, height)
    local baseCoords, heading = VRS.GetLiftBaseCoords(shopId, liftIndex)
    if not baseCoords then return nil end
    local clampedHeight = math.min(math.max(roundHeight(height), Config.Lift.MinHeight or 0.0), Config.Lift.MaxHeight or 2.1)
    local vehicleZ = baseCoords.z + clampedHeight + (Config.Lift.VehicleZOffset or 0.36)
    return vec3(baseCoords.x, baseCoords.y, vehicleZ), heading
end

function VRS.GetLiftHeightLabel(height)
    height = roundHeight(height)
    local presets = Config.Lift.DefaultWorkHeights or {}
    if math.abs(height - (Config.Lift.MinHeight or 0.0)) <= 0.05 then
        return 'Base'
    end
    if presets.engine and math.abs(height - presets.engine) <= 0.08 then
        return 'Motor'
    end
    if presets.wheel and math.abs(height - presets.wheel) <= 0.08 then
        return 'Serviço de roda/freio'
    end
    if presets.underbody and math.abs(height - presets.underbody) <= 0.08 then
        return 'Serviço inferior'
    end
    return ('%.2fm'):format(height)
end

function VRS.CanUseLift(shopId)
    local shop = Config.Shops[shopId]
    if not shop then return false end
    if shop.type ~= 'owned' then return true end
    if shop.job and not VRS.IsMechanic() then return false end
    if Config.Lift.requireDuty and not VRS.IsOnDuty() then return false end
    return true
end

function VRS.GetLiftPropData(shopId, liftIndex)
    local liftKey = getLiftKey(shopId, liftIndex)
    return spawnedLifts[liftKey]
end

function VRS.IsLiftMoving(shopId, liftIndex)
    local liftKey = getLiftKey(shopId, liftIndex)
    return liftMovement[liftKey] ~= nil
end

-- ============================================================
-- CONTROLE DE MOVIMENTO
-- ============================================================

function VRS.StartLiftMovement(shopId, liftIndex, direction)
    if not VRS.CanUseLift(shopId) then
        lib.notify({ title = 'Elevador', description = VRS.IsMechanic() and 'Você precisa estar em serviço.' or 'Sem permissão.', type = 'error' })
        return false
    end

    local liftKey = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftState[liftKey]

    if Config.Lift.requireVehicleToRaise and direction == 'up' then
        if not state or not state.vehicleNetId then
            lib.notify({ title = 'Elevador', description = 'Nenhum veículo no elevador.', type = 'error' })
            return false
        end
    end

    local result = lib.callback.await('vrs_mechanic:server:liftCommand', false, shopId, liftIndex, direction)
    if not result or not result.success then
        local messages = {
            no_access = 'Sem permissão para usar este elevador.',
            not_on_duty = 'Você precisa estar em serviço.',
            invalid_lift = 'Elevador inválido.',
            lift_busy = 'Elevador já em movimento.',
            lift_empty = 'Nenhum veículo no elevador.',
            already_top = 'Elevador já está na altura máxima.',
            already_bottom = 'Elevador já está na posição mínima.',
        }
        lib.notify({ title = 'Elevador', description = messages[result and result.reason or ''] or 'Erro ao operar elevador.', type = 'error' })
        return false
    end

    return true
end

function VRS.StopLiftMovement(shopId, liftIndex)
    local liftKey = getLiftKey(shopId, liftIndex)
    if not liftMovement[liftKey] then return end
    lib.callback.await('vrs_mechanic:server:liftCommand', false, shopId, liftIndex, 'stop')
end

function VRS.SetLiftPresetHeight(shopId, liftIndex, targetHeight)
    if not VRS.CanUseLift(shopId) then
        lib.notify({ title = 'Elevador', description = 'Sem permissão.', type = 'error' })
        return false
    end

    local result = lib.callback.await('vrs_mechanic:server:setLiftHeight', false, shopId, liftIndex, targetHeight)
    if not result or not result.success then
        local messages = {
            lift_empty = 'Nenhum veículo no elevador.',
            invalid_height = 'Altura inválida.',
            same_height = 'Já está nessa altura.',
        }
        lib.notify({ title = 'Elevador', description = messages[result and result.reason or ''] or 'Erro.', type = 'error' })
        return false
    end

    return true
end

-- ============================================================
-- SINCRONIZAÇÃO DE ESTADO
-- ============================================================

function VRS.ApplyLiftState(shopId, liftIndex, state)
    if not state then return end
    local liftKey = getLiftKey(shopId, liftIndex)

    local previousState = VRS.LiftState[liftKey] or {}
    VRS.LiftState[liftKey] = state
    VRS.OnLift[liftKey] = state.vehicleNetId

    -- Atualizar veículo anexado
    if state.vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            attachedVehicles[liftKey] = vehicle
        end
    else
        if attachedVehicles[liftKey] and DoesEntityExist(attachedVehicles[liftKey]) then
            requestControl(attachedVehicles[liftKey])
            FreezeEntityPosition(attachedVehicles[liftKey], false)
        end
        attachedVehicles[liftKey] = nil
    end

    -- Se veículo foi removido do elevador anterior
    if previousState.vehicleNetId and previousState.vehicleNetId ~= state.vehicleNetId then
        local prevVehicle = NetworkGetEntityFromNetworkId(previousState.vehicleNetId)
        if prevVehicle and prevVehicle ~= 0 and DoesEntityExist(prevVehicle) then
            requestControl(prevVehicle)
            FreezeEntityPosition(prevVehicle, false)
        end
    end

    -- Aplicar altura na plataforma e veículo
    local height = state.height or Config.Lift.MinHeight or 0.0
    setPlatformHeight(liftKey, height)
    updateVehicleOnLift(liftKey, height)
end

function VRS.RefreshLiftState(shopId, liftIndex)
    local state = lib.callback.await('vrs_mechanic:server:getLiftState', false, shopId, liftIndex)
    if state then
        VRS.ApplyLiftState(shopId, liftIndex, state)
    end
    return state
end

RegisterNetEvent('vrs_mechanic:client:syncLiftState', function(shopId, liftIndex, state)
    VRS.ApplyLiftState(shopId, liftIndex, state)
end)

RegisterNetEvent('vrs_mechanic:client:syncLiftLayouts', function(layouts)
    VRS.ApplyLiftLayouts(layouts)
end)

RegisterNetEvent('vrs_mechanic:client:liftMovement', function(shopId, liftIndex, direction)
    local liftKey = getLiftKey(shopId, liftIndex)
    if direction == 'stop' then
        liftMovement[liftKey] = nil
    else
        liftMovement[liftKey] = direction
    end
end)

-- ============================================================
-- PAINEL NUI
-- ============================================================

local activePanelLift = nil -- { shopId, liftIndex }

function VRS.OpenLiftPanel(shopId, liftIndex)
    if not VRS.CanUseLift(shopId) then
        lib.notify({ title = 'Elevador', description = 'Sem permissão.', type = 'error' })
        return
    end

    VRS.RefreshLiftState(shopId, liftIndex)
    activePanelLift = { shopId = shopId, liftIndex = liftIndex }

    local liftKey = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftState[liftKey] or {}
    local shop = Config.Shops[shopId]

    local vehiclePlate = nil
    if state.vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            vehiclePlate = VRS.GetPlate(vehicle)
        end
    end

    SendNUIMessage({
        action = 'openLiftPanel',
        shopLabel = shop and shop.label or 'Oficina',
        liftIndex = liftIndex,
        height = roundHeight(state.height or 0.0),
        maxHeight = Config.Lift.MaxHeight or 2.1,
        minHeight = Config.Lift.MinHeight or 0.0,
        hasVehicle = state.vehicleNetId ~= nil,
        vehiclePlate = vehiclePlate or state.plate,
        moving = liftMovement[liftKey] ~= nil,
        direction = liftMovement[liftKey],
        heightLabel = VRS.GetLiftHeightLabel(state.height or 0.0),
        levels = Config.Lift.levels,
    })

    SetNuiFocus(true, true)
end

function VRS.CloseLiftPanel()
    activePanelLift = nil
    SendNUIMessage({ action = 'closeLiftPanel' })
    SetNuiFocus(false, false)
end

function VRS.UpdateLiftPanel()
    if not activePanelLift then return end
    local shopId = activePanelLift.shopId
    local liftIndex = activePanelLift.liftIndex
    local liftKey = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftState[liftKey] or {}

    local vehiclePlate = nil
    if state.vehicleNetId then
        local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
            vehiclePlate = VRS.GetPlate(vehicle)
        end
    end

    SendNUIMessage({
        action = 'updateLiftPanel',
        height = roundHeight(state.height or 0.0),
        hasVehicle = state.vehicleNetId ~= nil,
        vehiclePlate = vehiclePlate or state.plate,
        moving = liftMovement[liftKey] ~= nil,
        direction = liftMovement[liftKey],
        heightLabel = VRS.GetLiftHeightLabel(state.height or 0.0),
    })
end

-- NUI Callbacks
RegisterNUICallback('liftAction', function(data, cb)
    cb('ok')
    if not activePanelLift then return end

    local shopId = activePanelLift.shopId
    local liftIndex = activePanelLift.liftIndex
    local action = data.action

    if action == 'up' then
        VRS.StartLiftMovement(shopId, liftIndex, 'up')
    elseif action == 'down' then
        VRS.StartLiftMovement(shopId, liftIndex, 'down')
    elseif action == 'stop' then
        VRS.StopLiftMovement(shopId, liftIndex)
    elseif action == 'preset' and data.height then
        VRS.SetLiftPresetHeight(shopId, liftIndex, tonumber(data.height))
    elseif action == 'close' then
        VRS.CloseLiftPanel()
    end
end)

RegisterNUICallback('closeLiftPanel', function(_, cb)
    cb('ok')
    VRS.CloseLiftPanel()
end)

-- ============================================================
-- LOOP DE MOVIMENTO CONTÍNUO
-- ============================================================

CreateThread(function()
    local syncTimer = 0
    while true do
        local hasMovement = false

        for liftKey, direction in pairs(liftMovement) do
            hasMovement = true
            local data = spawnedLifts[liftKey]
            if data and data.platform and DoesEntityExist(data.platform) then
                local currentHeight = getPlatformCurrentHeight(liftKey)
                local maxH = Config.Lift.MaxHeight or 2.1
                local minH = Config.Lift.MinHeight or 0.0
                local slowZone = Config.Lift.SlowZoneSize or 0.15
                local newHeight = currentHeight

                if direction == 'up' and currentHeight < maxH then
                    local speed = (currentHeight > maxH - slowZone)
                        and (Config.Lift.SpeedSlow or 0.0006)
                        or (Config.Lift.SpeedUp or 0.0012)
                    newHeight = math.min(currentHeight + speed, maxH)
                elseif direction == 'down' and currentHeight > minH then
                    local speed = (currentHeight < minH + slowZone)
                        and (Config.Lift.SpeedSlow or 0.0006)
                        or (Config.Lift.SpeedDown or 0.0018)
                    newHeight = math.max(currentHeight - speed, minH)
                end

                if newHeight ~= currentHeight then
                    setPlatformHeight(liftKey, newHeight)
                    updateVehicleOnLift(liftKey, newHeight)

                    -- Atualizar estado local
                    if VRS.LiftState[liftKey] then
                        VRS.LiftState[liftKey].height = roundHeight(newHeight)
                    end
                end

                -- Verificar se atingiu altura alvo (presets)
                local state = VRS.LiftState[liftKey]
                local targetH = state and state.targetHeight
                local reachedTarget = false
                if targetH then
                    if (direction == 'up' and newHeight >= targetH) or
                       (direction == 'down' and newHeight <= targetH) then
                        newHeight = targetH
                        setPlatformHeight(liftKey, newHeight)
                        updateVehicleOnLift(liftKey, newHeight)
                        if state then state.height = roundHeight(newHeight) end
                        reachedTarget = true
                    end
                end

                -- Parar automaticamente nos limites ou no alvo
                if reachedTarget or (direction == 'up' and newHeight >= maxH) or (direction == 'down' and newHeight <= minH) then
                    liftMovement[liftKey] = nil
                    -- Extrair shopId e liftIndex do key
                    local parts = {}
                    for part in liftKey:gmatch('[^_]+') do
                        parts[#parts + 1] = part
                    end
                    local lIdx = tonumber(parts[#parts])
                    local sId = table.concat(parts, '_', 1, #parts - 1)
                    if sId and lIdx then
                        lib.callback.await('vrs_mechanic:server:liftCommand', false, sId, lIdx, 'stop')
                    end
                end
            end
        end

        -- Sincronizar altura com server periodicamente
        if hasMovement then
            syncTimer = syncTimer + 1
            if syncTimer >= 30 then -- a cada ~30 frames
                syncTimer = 0
                for liftKey, _ in pairs(liftMovement) do
                    local data = spawnedLifts[liftKey]
                    if data then
                        local h = getPlatformCurrentHeight(liftKey)
                        -- Extrair shopId e liftIndex
                        local parts = {}
                        for part in liftKey:gmatch('[^_]+') do
                            parts[#parts + 1] = part
                        end
                        local lIdx = tonumber(parts[#parts])
                        local sId = table.concat(parts, '_', 1, #parts - 1)
                        if sId and lIdx then
                            TriggerServerEvent('vrs_mechanic:server:syncLiftHeight', sId, lIdx, h)
                        end
                    end
                end
            end
        end

        -- Atualizar painel NUI se aberto
        if activePanelLift and hasMovement then
            VRS.UpdateLiftPanel()
        end

        Wait(hasMovement and 0 or 500)
    end
end)

-- ============================================================
-- DESABILITAR COLISÃO VEÍCULO/PLATAFORMA
-- ============================================================

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then
            for liftKey, data in pairs(spawnedLifts) do
                if data.platform and DoesEntityExist(data.platform) then
                    local platformCoords = GetEntityCoords(data.platform)
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local dist = #(platformCoords - vehicleCoords)
                    if dist < 8.0 and not attachedVehicles[liftKey] then
                        SetEntityNoCollisionEntity(data.platform, vehicle, true)
                        SetEntityNoCollisionEntity(vehicle, data.platform, true)
                    end
                end
            end
        end

        Wait(vehicle ~= 0 and 0 or 1000)
    end
end)

-- ============================================================
-- SPAWNING INICIAL
-- ============================================================

CreateThread(function()
    Wait(1500)

    local response = fetchLiftLayoutsSafe()
    if response and response.layouts then
        VRS.ApplyLiftLayouts(response.layouts)
    else
        VRS.RebuildLiftProps(true)
    end

    TriggerServerEvent('vrs_mechanic:server:requestLiftLayouts')
end)

-- ============================================================
-- CLEANUP
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for liftKey in pairs(liftMovement) do
        liftMovement[liftKey] = nil
    end

    for liftKey in pairs(spawnedLifts) do
        destroyLiftProps(liftKey)
    end

    if activePanelLift then
        VRS.CloseLiftPanel()
    end
end)
