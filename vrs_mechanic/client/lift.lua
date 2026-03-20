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
-- SPAWN / DETECÇÃO UNIVERSAL DE ELEVADORES
-- ============================================================

local function rotateOffset(offset, heading)
    local radians = math.rad(heading or 0.0)
    local cosHeading = math.cos(radians)
    local sinHeading = math.sin(radians)

    return vec3(
        (offset.x * cosHeading) - (offset.y * sinHeading),
        (offset.x * sinHeading) + (offset.y * cosHeading),
        offset.z or 0.0
    )
end

local function getLiftEntry(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    return shop and shop.lifts and shop.lifts[liftIndex] or nil
end

local function getLiftMetrics(shopId, liftIndex)
    return VRS.GetLiftMetrics(getLiftEntry(shopId, liftIndex) or {})
end

local function getLiftHashMap()
    local results = {}
    for profileName, profile in pairs(Config.Lift.Models or {}) do
        if profileName ~= 'standard_lift' and (profile.useExistingEntity or profile.sourceType == 'world' or profile.sourceType == 'world_or_spawned') then
            local hash = VRS.ResolveModelHash(profile.model or profileName)
            if hash then
                results[hash] = profile.model or profileName
            end
        end
    end
    return results
end

local function serializeVec3(value)
    if not value then return nil end
    return { x = value.x, y = value.y, z = value.z }
end

local function findLiftEntity(lift, metrics)
    if not metrics.useExistingEntity then return nil end

    local targetCoords = vec3(lift.coords.x, lift.coords.y, lift.coords.z)
    local heading = lift.coords.w or 0.0
    local entityOffset = rotateOffset(metrics.platformOffset or vec3(0.0, 0.0, 0.0), heading)
    local expectedEntityCoords = targetCoords - entityOffset
    local modelHash = VRS.ResolveModelHash(lift.model or metrics.profileName)
    if not modelHash then return nil end

    local bestEntity, bestDist = nil, 4.0
    for _, entity in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(entity) and GetEntityModel(entity) == modelHash then
            local dist = #(GetEntityCoords(entity) - expectedEntityCoords)
            if dist <= bestDist then
                bestEntity = entity
                bestDist = dist
            end
        end
    end

    return bestEntity
end

local function spawnPoles(platformEntity, heading, profile)
    local poles = {}
    local poleModel = profile.poleModel or Config.Lift.PoleModel
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

local function spawnElecBox(platformEntity, heading, profile)
    local offset = profile.elecBoxOffset or Config.Lift.ElecBoxOffset or vec3(0.0, -3.3, -0.7)
    local worldCoords = GetOffsetFromEntityInWorldCoords(platformEntity, offset.x, offset.y, offset.z)
    return createProp(profile.elecBoxModel or Config.Lift.ElecBoxModel, worldCoords.x, worldCoords.y, worldCoords.z, heading)
end

local function estimateLiftSize(entity, metrics)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(entity))
    local length = metrics.length
    local width = metrics.width

    if (Config.Lift.ModelDefaults and Config.Lift.ModelDefaults.fallbackToModelDimensions) or metrics.profile.fallbackToModelDimensions then
        length = math.max(length or 0.0, math.abs(maxDim.y - minDim.y))
        width = math.max(width or 0.0, math.abs(maxDim.x - minDim.x))
    end

    return length > 0.0 and length or 5.0, width > 0.0 and width or 2.5
end

function VRS.GetNearestCompatibleWorldLift(maxDistance, shopId)
    local hashMap = getLiftHashMap()
    local pedCoords = GetEntityCoords(cache.ped)
    local best, bestDist = nil, maxDistance or 10.0

    for _, entity in ipairs(GetGamePool('CObject')) do
        local modelName = hashMap[GetEntityModel(entity)]
        if modelName then
            local entityCoords = GetEntityCoords(entity)
            local dist = #(pedCoords - entityCoords)
            if dist <= bestDist then
                if not shopId or VRS.IsPointInsideShopZone(shopId, entityCoords) then
                    local profile = VRS.GetLiftModelProfile(modelName)
                    local heading = GetEntityHeading(entity)
                    local platformOffset = rotateOffset(profile.platformOffset or vec3(0.0, 0.0, 0.0), heading)
                    local platformCoords = entityCoords + platformOffset
                    local length, width = estimateLiftSize(entity, VRS.GetLiftMetrics({ model = modelName }))
                    best = {
                        id = ('%s:%d:%.2f:%.2f:%.2f'):format(modelName, GetEntityModel(entity), platformCoords.x, platformCoords.y, platformCoords.z),
                        entity = entity,
                        model = modelName,
                        coords = vec4(platformCoords.x, platformCoords.y, platformCoords.z, heading),
                        length = length,
                        width = width,
                        minHeight = profile.minHeight,
                        maxHeight = profile.maxHeight,
                        platformOffset = serializeVec3(profile.platformOffset or vec3(0.0, 0.0, 0.0)),
                        vehicleOffset = serializeVec3(profile.vehicleOffset or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36)),
                        interactionOffset = serializeVec3(profile.interactionOffset or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0)),
                        metadata = {
                            modelHash = GetEntityModel(entity),
                            source = 'world_scan',
                        },
                    }
                    bestDist = dist
                end
            end
        end
    end

    return best, bestDist
end

function VRS.ScanWorldLifts(shopId)
    if not Config.Lift.WorldDetection or not Config.Lift.WorldDetection.enabled then return end
    local shop = Config.Shops[shopId]
    if not shop or not shop.zones or not shop.zones.main then return end

    local hashMap = getLiftHashMap()
    local found = {}
    local zoneCoords = shop.zones.main.coords
    local maxDistance = Config.Lift.WorldDetection.maxDistanceFromShop or 45.0

    for _, entity in ipairs(GetGamePool('CObject')) do
        local modelName = hashMap[GetEntityModel(entity)]
        if modelName then
            local entityCoords = GetEntityCoords(entity)
            if #(entityCoords - zoneCoords) <= maxDistance then
                local duplicate = false
                for _, existing in ipairs(found) do
                    local dist = #(vec3(existing.coords.x, existing.coords.y, existing.coords.z) - entityCoords)
                    if dist <= (Config.Lift.WorldDetection.dedupeDistance or 1.5) and existing.model == modelName then
                        duplicate = true
                        break
                    end
                end

                if not duplicate then
                    local profile = VRS.GetLiftModelProfile(modelName)
                    local metrics = VRS.GetLiftMetrics({ model = modelName })
                    local heading = GetEntityHeading(entity)
                    local platformOffset = rotateOffset(profile.platformOffset or vec3(0.0, 0.0, 0.0), heading)
                    local platformCoords = entityCoords + platformOffset
                    local length, width = estimateLiftSize(entity, metrics)
                    found[#found + 1] = {
                        model = modelName,
                        coords = { x = platformCoords.x, y = platformCoords.y, z = platformCoords.z, w = heading },
                        length = length,
                        width = width,
                        minHeight = profile.minHeight,
                        maxHeight = profile.maxHeight,
                        platformOffset = serializeVec3(profile.platformOffset or vec3(0.0, 0.0, 0.0)),
                        vehicleOffset = serializeVec3(profile.vehicleOffset or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36)),
                        interactionOffset = serializeVec3(profile.interactionOffset or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0)),
                        metadata = { modelHash = GetEntityModel(entity), discovered = true },
                    }
                end
            end
        end
    end

    TriggerServerEvent('vrs_mechanic:server:registerWorldLifts', shopId, found)
    return found
end

local function spawnLiftProps(shopId, liftIndex)
    local liftKey = getLiftKey(shopId, liftIndex)
    if spawnedLifts[liftKey] then return spawnedLifts[liftKey] end

    local lift = getLiftEntry(shopId, liftIndex)
    if not lift then return nil end

    local x, y, z = lift.coords.x, lift.coords.y, lift.coords.z
    local heading = lift.coords.w or 0.0
    local metrics = getLiftMetrics(shopId, liftIndex)
    local profile = metrics.profile
    local platform = nil
    local poles = {}
    local elecbox = nil
    local spawned = false

    if profile.sourceType == 'spawned_composite' or lift.model == 'standard_lift' then
        platform = createProp(profile.platformModel or Config.Lift.PlatformModel, x, y, z, heading)
        if not platform or platform == 0 then return nil end
        spawned = true

        if profile.spawnPoles ~= false and Config.Lift.SpawnPoles then
            poles = spawnPoles(platform, heading, profile)
        end

        if profile.spawnElecBox ~= false and Config.Lift.SpawnElecBox then
            elecbox = spawnElecBox(platform, heading, profile)
        end
    else
        platform = findLiftEntity(lift, metrics)
        if not platform and not metrics.useExistingEntity then
            local entityOffset = rotateOffset(metrics.platformOffset or vec3(0.0, 0.0, 0.0), heading)
            local spawnCoords = vec3(x, y, z) - entityOffset
            platform = createProp(lift.model or profile.model, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading)
            spawned = platform ~= nil
        end

        if not platform or platform == 0 then return nil end
    end

    spawnedLifts[liftKey] = {
        platform = platform,
        poles = poles,
        elecbox = elecbox,
        baseZ = z,
        heading = heading,
        baseCoords = vec3(x, y, z),
        entityOffset = metrics.platformOffset or vec3(0.0, 0.0, 0.0),
        vehicleOffset = metrics.vehicleOffset or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36),
        interactionOffset = metrics.interactionOffset or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0),
        metrics = metrics,
        spawned = spawned,
    }

    return spawnedLifts[liftKey]
end

local function destroyLiftProps(liftKey)
    local data = spawnedLifts[liftKey]
    if not data then return end

    if data.spawned and data.platform and DoesEntityExist(data.platform) then
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
    local platformZ = currentZ + (data.entityOffset and data.entityOffset.z or 0.0)
    return roundHeight(platformZ - data.baseZ)
end

local function setPlatformHeight(liftKey, height)
    local data = spawnedLifts[liftKey]
    if not data or not data.platform or not DoesEntityExist(data.platform) then return end

    local targetPlatformZ = data.baseZ + height
    local targetEntityCoords = vec3(data.baseCoords.x, data.baseCoords.y, targetPlatformZ) - (data.entityOffset or vec3(0.0, 0.0, 0.0))
    FreezeEntityPosition(data.platform, false)
    SetEntityCoordsNoOffset(data.platform, targetEntityCoords.x, targetEntityCoords.y, targetEntityCoords.z, false, false, false)
    FreezeEntityPosition(data.platform, true)
end

local function updateVehicleOnLift(liftKey, height)
    local vehicle = attachedVehicles[liftKey]
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local data = spawnedLifts[liftKey]
    if not data then return end

    local vehicleOffset = data.vehicleOffset or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36)
    local vehicleCoords = vec3(data.baseCoords.x, data.baseCoords.y, data.baseZ + height) + vehicleOffset
    requestControl(vehicle)
    SetEntityCoordsNoOffset(vehicle, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, false, false, false)
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
    local metrics = getLiftMetrics(shopId, liftIndex)
    local clampedHeight = math.min(math.max(roundHeight(height), metrics.minHeight), metrics.maxHeight)
    local vehicleCoords = vec3(baseCoords.x, baseCoords.y, baseCoords.z + clampedHeight) + metrics.vehicleOffset
    return vehicleCoords, heading
end

function VRS.GetLiftHeightLabel(height, shopId, liftIndex)
    height = roundHeight(height)
    local metrics = (shopId and liftIndex) and getLiftMetrics(shopId, liftIndex) or nil
    local presets = Config.Lift.DefaultWorkHeights or {}
    local minHeight = metrics and metrics.minHeight or (Config.Lift.MinHeight or 0.0)
    if math.abs(height - minHeight) <= 0.05 then
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
    local height = state.height or state.minHeight or Config.Lift.MinHeight or 0.0
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
        maxHeight = state.maxHeight or Config.Lift.MaxHeight or 2.1,
        minHeight = state.minHeight or Config.Lift.MinHeight or 0.0,
        hasVehicle = state.vehicleNetId ~= nil,
        vehiclePlate = vehiclePlate or state.plate,
        moving = liftMovement[liftKey] ~= nil,
        direction = liftMovement[liftKey],
        heightLabel = VRS.GetLiftHeightLabel(state.height or 0.0, shopId, liftIndex),
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
        heightLabel = VRS.GetLiftHeightLabel(state.height or 0.0, shopId, liftIndex),
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
                local maxH = (VRS.LiftState[liftKey] and VRS.LiftState[liftKey].maxHeight) or Config.Lift.MaxHeight or 2.1
                local minH = (VRS.LiftState[liftKey] and VRS.LiftState[liftKey].minHeight) or Config.Lift.MinHeight or 0.0
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

    if Config.Lift.WorldDetection and Config.Lift.WorldDetection.discoverOnStart then
        for shopId in pairs(Config.Shops) do
            VRS.ScanWorldLifts(shopId)
        end
    end
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
