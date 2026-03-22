-- ============================================================
-- VRS_MECHANIC - CLIENT MAIN
-- ============================================================

VRS = VRS or {}
VRS.LoadLocale()

-- Cache local de status de veículos
VRS.VehicleStatus = {}

-- Estado do jogador
VRS.CurrentShop = nil   -- shopId da oficina atual
VRS.InShopZone = false
VRS.OnLift = {}         -- { [liftIndex] = netId }
VRS.LiftState = {}


VRS.OpenLiftAdminMenu = VRS.OpenLiftAdminMenu or function()
    lib.notify({ title = 'Elevador', description = 'Gerenciamento de elevadores indisponível no momento.', type = 'error' })
end

VRS.OpenLiftMenu = VRS.OpenLiftMenu or function()
    error('[vrs_mechanic] OpenLiftMenu não foi inicializada. Verifique a ordem dos client_scripts no fxmanifest.', 2)
end

VRS.ApplyLiftLayouts = VRS.ApplyLiftLayouts or function() end
VRS.RebuildLiftTargets = VRS.RebuildLiftTargets or function() end
VRS.FetchLiftAdminData = VRS.FetchLiftAdminData or function() return nil end

function VRS.RequireClientFunction(name)
    local fn = VRS[name]
    if type(fn) ~= 'function' then
        error(('[vrs_mechanic] Função client %s indisponível. Verifique carregamento/escopo do módulo.'):format(tostring(name)), 2)
    end

    return fn
end

function VRS.IsValidVehicleEntity(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and IsEntityAVehicle(entity)
end

function VRS.GetEntityFromNetId(netId, requireVehicle)
    local numericNetId = tonumber(netId)
    if not numericNetId or numericNetId <= 0 then
        return nil, 'invalid_netid'
    end

    if NetworkDoesNetworkIdExist and not NetworkDoesNetworkIdExist(numericNetId) then
        return nil, 'missing_network_object'
    end

    local entity = NetworkGetEntityFromNetworkId(numericNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil, 'missing_entity'
    end

    if requireVehicle and not IsEntityAVehicle(entity) then
        return nil, 'not_vehicle'
    end

    return entity, nil
end

function VRS.GetSafeNetId(entity)
    if not VRS.IsValidVehicleEntity(entity) then
        return nil, 'invalid_vehicle'
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        return nil, 'missing_network_id'
    end

    return netId, nil
end

function VRS.GetLiftStateSnapshot(shopId, liftIndex)
    local resolvedLift = VRS.ResolveLiftReference(shopId, liftIndex)
    if not resolvedLift then
        return {
            shopId = shopId,
            liftIndex = liftIndex,
            height = Config.Lift.MinHeight or 0.0,
            minHeight = Config.Lift.MinHeight or 0.0,
            maxHeight = Config.Lift.MaxHeight or 2.1,
            vehicleNetId = nil,
            plate = nil,
            moving = false,
            direction = nil,
        }
    end

    local cached = VRS.LiftState and VRS.LiftState[resolvedLift.liftKey] or nil
    if cached then
        return cached
    end

    return {
        shopId = resolvedLift.shopId,
        liftIndex = resolvedLift.liftIndex,
        height = Config.Lift.MinHeight or 0.0,
        minHeight = Config.Lift.MinHeight or 0.0,
        maxHeight = Config.Lift.MaxHeight or 2.1,
        vehicleNetId = nil,
        plate = nil,
        moving = false,
        direction = nil,
    }
end

VRS.RefreshLiftState = VRS.RefreshLiftState or function(shopId, liftIndex)
    return VRS.GetLiftStateSnapshot(shopId, liftIndex)
end

-- ============================================================
-- SYNC DE STATUS
-- ============================================================

RegisterNetEvent('vrs_mechanic:client:syncVehicleStatus', function(plate, status)
    if not plate then return end
    VRS.VehicleStatus[plate] = status
end)

--- Obtém status local do veículo (ou requisita ao server)
---@param plate string
---@return table|nil
function VRS.GetLocalStatus(plate)
    if VRS.VehicleStatus[plate] then
        return VRS.VehicleStatus[plate]
    end

    local status = lib.callback.await('vrs_mechanic:server:getVehicleStatus', false, plate)
    if status then
        VRS.VehicleStatus[plate] = status
    end
    return status
end

-- ============================================================
-- SETUP AO ENTRAR EM VEÍCULO
-- ============================================================

lib.onCache('vehicle', function(vehicle)
    if not vehicle then return end

    local plate = VRS.GetPlate(vehicle)
    if not plate then return end

    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)

    TriggerServerEvent('vrs_mechanic:server:setupVehicleStatus', plate, engineHealth, bodyHealth)
end)

-- ============================================================
-- SALVAR STATUS AO SAIR DO VEÍCULO
-- ============================================================

RegisterNetEvent('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkPlayerEnteredVehicle' then return end
    -- Será tratado pelo lib.onCache acima
end)

local function handleVehicleExitSave(lastVehicle)
    local vehicle = cache.vehicle

    if not vehicle and lastVehicle then
        local plate = VRS.GetPlate(lastVehicle)
        if plate then
            TriggerServerEvent('vrs_mechanic:server:saveVehicleStatus', plate)
        end
    end

    return vehicle
end

-- ============================================================
-- APLICAR EFEITOS DE STATUS NO VEÍCULO
-- ============================================================

local function applyVehicleStatusEffects()
    local vehicle = cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    local plate = VRS.GetPlate(vehicle)
    local status = plate and VRS.VehicleStatus[plate] or nil
    if not status then
        return true
    end

    local targetEngine = status.engine or Config.MaxStatus.engine
    local currentEngine = GetVehicleEngineHealth(vehicle)
    if math.abs(currentEngine - targetEngine) > 50 then
        SetVehicleEngineHealth(vehicle, targetEngine)
    end

    local targetBody = status.body or Config.MaxStatus.body
    local currentBody = GetVehicleBodyHealth(vehicle)
    if math.abs(currentBody - targetBody) > 50 then
        SetVehicleBodyHealth(vehicle, targetBody)
    end

    local brakesPct = VRS.GetPartPercent('brakes', status.brakes or 0)
    if brakesPct < 30 then
        local efficiency = Config.Degradation.brakesMinEfficiency +
            (1 - Config.Degradation.brakesMinEfficiency) * (brakesPct / 30)
        SetVehicleHandbrake(vehicle, false)
        SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', efficiency)
    end

    local transPct = VRS.GetPartPercent('transmission', status.transmission or 0)
    if transPct < 50 then
        local torqueLoss = Config.Degradation.transmissionTorqueLoss * (1 - transPct / 50)
        local torqueMult = 1.0 - torqueLoss
        SetVehicleCheatPowerIncrease(vehicle, torqueMult - 1.0)
    end

    return true
end

if not VRS.IsExperimentalEnabled('ClientLoopOptimization') then
    CreateThread(function()
        local lastVehicle = nil
        while true do
            Wait(1000)
            lastVehicle = handleVehicleExitSave(lastVehicle)
        end
    end)

    CreateThread(function()
        while true do
            local hasVehicle = applyVehicleStatusEffects()
            Wait(hasVehicle and 2000 or 3000)
        end
    end)
else
    CreateThread(function()
        VRS.DebugLog('clientLoops', 'Scheduler otimizado de status do client ativado.')

        local lastVehicle = nil
        local lastExitCheck = 0
        local lastStatusTick = 0

        while true do
            local tickStartedAt = GetGameTimer()
            local now = tickStartedAt

            if now - lastExitCheck >= 1000 then
                lastExitCheck = now
                lastVehicle = handleVehicleExitSave(lastVehicle)
            end

            if now - lastStatusTick >= (cache.vehicle and 2000 or 3000) then
                lastStatusTick = now
                applyVehicleStatusEffects()
            end

            VRS.DebugMeasure('clientLoops', 'client.main.scheduler', tickStartedAt)
            Wait(cache.vehicle and 250 or 750)
        end
    end)
end

-- ============================================================
-- UTILIDADES DO CLIENT
-- ============================================================

--- Obtém o veículo mais próximo do jogador
---@param maxDist number
---@return number|nil vehicle, number|nil distance
function VRS.GetClosestVehicle(maxDist)
    maxDist = maxDist or 5.0
    local coords = GetEntityCoords(cache.ped)
    local vehicles = GetGamePool('CVehicle')
    local closest, closestDist = nil, maxDist

    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vehCoords = GetEntityCoords(veh)
            local dist = #(coords - vehCoords)
            if dist < closestDist then
                closest = veh
                closestDist = dist
            end
        end
    end

    return closest, closestDist
end

local function isPointInsideLegacyShopZone(zone, coords)
    return #(vec3(coords.x, coords.y, coords.z) - zone.coords) <= math.max(zone.size.x, zone.size.y)
end

local function isPointInsideRotatedBoxZone(zone, coords)
    local rotation = math.rad(-(zone.rotation or 0.0))
    local delta = vec3(coords.x, coords.y, coords.z) - zone.coords
    local localX = (delta.x * math.cos(rotation)) - (delta.y * math.sin(rotation))
    local localY = (delta.x * math.sin(rotation)) + (delta.y * math.cos(rotation))
    local halfSize = vec3(
        (zone.size and zone.size.x or 0.0) * 0.5,
        (zone.size and zone.size.y or 0.0) * 0.5,
        (zone.size and zone.size.z or 0.0) * 0.5
    )

    return math.abs(localX) <= halfSize.x and
        math.abs(localY) <= halfSize.y and
        math.abs(delta.z) <= math.max(halfSize.z, 2.5)
end

--- Valida se um ponto está dentro da área principal da oficina
---@param shopId string
---@param coords vector3
---@return boolean
function VRS.IsPointInsideShopZone(shopId, coords)
    local shop = Config.Shops[shopId]
    local zone = shop and shop.zones and shop.zones.main
    if not zone then return false end

    local useRotatedGeometry = VRS.IsExperimentalEnabled('RotatedWorkshopZones') and zone.size and zone.rotation ~= nil
    if useRotatedGeometry then
        local ok, inside = pcall(isPointInsideRotatedBoxZone, zone, coords)
        if ok then
            return inside
        end
    end

    return isPointInsideLegacyShopZone(zone, coords)
end

--- Verifica se jogador tem o job de mecânico
---@return boolean
function VRS.IsMechanic()
    local job = QBX.PlayerData.job
    if not job then return false end

    for _, shop in pairs(Config.Shops) do
        if shop.job and job.name == shop.job then
            return true
        end
    end
    return false
end

--- Verifica se jogador está em duty
---@return boolean
function VRS.IsOnDuty()
    local job = QBX.PlayerData.job
    return job and job.onduty == true
end

--- Obtém shopId do job atual
---@return string|nil
function VRS.GetPlayerShopId()
    local job = QBX.PlayerData.job
    if not job then return nil end

    for shopId, shop in pairs(Config.Shops) do
        if shop.job and job.name == shop.job then
            return shopId
        end
    end
    return nil
end

-- ============================================================
-- EXPORTS
-- ============================================================

exports('GetVehicleStatusList', function(plate)
    return VRS.VehicleStatus[plate]
end)

exports('GetVehicleStatus', function(plate, part)
    local targetPart = VRS.NormalizePartName(part)
    if VRS.VehicleStatus[plate] and targetPart then
        return VRS.VehicleStatus[plate][targetPart]
    end
    return nil
end)

exports('SetVehicleStatus', function(plate, part, level)
    local targetPart = VRS.NormalizePartName(part)
    if not targetPart then return end
    TriggerServerEvent('vrs_mechanic:server:updatePart', plate, targetPart, level, cache.vehicle and NetworkGetNetworkIdFromEntity(cache.vehicle) or nil)
end)

print('[vrs_mechanic] ^2Cliente iniciado^0')
