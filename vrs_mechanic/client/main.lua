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

VRS.ApplyLiftLayouts = VRS.ApplyLiftLayouts or function() end
VRS.RebuildLiftTargets = VRS.RebuildLiftTargets or function() end
VRS.FetchLiftAdminData = VRS.FetchLiftAdminData or function() return nil end

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

-- Salvar ao sair do veículo
CreateThread(function()
    local lastVehicle = nil
    while true do
        Wait(1000)
        local vehicle = cache.vehicle

        if not vehicle and lastVehicle then
            local plate = VRS.GetPlate(lastVehicle)
            if plate then
                TriggerServerEvent('vrs_mechanic:server:saveVehicleStatus', plate)
            end
        end

        lastVehicle = vehicle
    end
end)

-- ============================================================
-- APLICAR EFEITOS DE STATUS NO VEÍCULO
-- ============================================================

CreateThread(function()
    while true do
        local vehicle = cache.vehicle
        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)
            if plate and VRS.VehicleStatus[plate] then
                local status = VRS.VehicleStatus[plate]

                -- Sincronizar engine/body health com status
                local enginePct = VRS.GetPartPercent('engine', status.engine or 0)
                local bodyPct = VRS.GetPartPercent('body', status.body or 0)

                -- Aplicar engine health
                local targetEngine = status.engine or Config.MaxStatus.engine
                local currentEngine = GetVehicleEngineHealth(vehicle)
                if math.abs(currentEngine - targetEngine) > 50 then
                    SetVehicleEngineHealth(vehicle, targetEngine)
                end

                -- Aplicar body health
                local targetBody = status.body or Config.MaxStatus.body
                local currentBody = GetVehicleBodyHealth(vehicle)
                if math.abs(currentBody - targetBody) > 50 then
                    SetVehicleBodyHealth(vehicle, targetBody)
                end

                -- Efeito: freios desgastados
                local brakesPct = VRS.GetPartPercent('brakes', status.brakes or 0)
                if brakesPct < 30 then
                    local efficiency = Config.Degradation.brakesMinEfficiency +
                        (1 - Config.Degradation.brakesMinEfficiency) * (brakesPct / 30)
                    SetVehicleHandbrake(vehicle, false)
                    -- Reduzir eficiência de frenagem via handling
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', efficiency)
                end

                -- Efeito: transmissão ruim
                local transPct = VRS.GetPartPercent('transmission', status.transmission or 0)
                if transPct < 50 then
                    local torqueLoss = Config.Degradation.transmissionTorqueLoss * (1 - transPct / 50)
                    local torqueMult = 1.0 - torqueLoss
                    SetVehicleCheatPowerIncrease(vehicle, torqueMult - 1.0)
                end
            end

            Wait(2000)
        else
            Wait(3000)
        end
    end
end)

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

--- Valida se um ponto está dentro da área principal da oficina
---@param shopId string
---@param coords vector3
---@return boolean
function VRS.IsPointInsideShopZone(shopId, coords)
    local shop = Config.Shops[shopId]
    local zone = shop and shop.zones and shop.zones.main
    if not zone then return false end
    return #(vec3(coords.x, coords.y, coords.z) - zone.coords) <= math.max(zone.size.x, zone.size.y)
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
    if VRS.VehicleStatus[plate] then
        return VRS.VehicleStatus[plate][part]
    end
    return nil
end)

exports('SetVehicleStatus', function(plate, part, level)
    TriggerServerEvent('vrs_mechanic:server:updatePart', plate, part, level, cache.vehicle and NetworkGetNetworkIdFromEntity(cache.vehicle) or nil)
end)

print('[vrs_mechanic] ^2Cliente iniciado^0')
