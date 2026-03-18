local State = {
    activeServicesByVehicle = {},
    activeServiceByPlayer = {},
    cooldowns = {},
    serviceVehicles = {}
}

local Validators = {}

local function notify(src, nType, message)
    TriggerClientEvent('ox_lib:notify', src, { type = nType, description = message })
end

local function log(...)
    DebugLog(...)
end

local function getPlayer(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    return exports.qbx_core:GetPlayer(src)
end

function Validators.player(src)
    local player = getPlayer(src)
    if not player then return false, nil, nil, L('invalid_player') end

    local job = player.PlayerData and player.PlayerData.job
    if not job then return false, player, nil, L('no_permission') end

    return true, player, job
end

function Validators.mechanic(src)
    local ok, player, job, err = Validators.player(src)
    if not ok then return false, player, job, err end

    if job.name ~= Config.MechanicJob then
        return false, player, job, L('no_permission')
    end

    return true, player, job
end

function Validators.duty(src)
    local ok, player, job, err = Validators.mechanic(src)
    if not ok then return false, player, job, err end

    if Config.RequireDuty and not job.onduty then
        return false, player, job, L('off_duty_blocked')
    end

    return true, player, job
end

function Validators.vehicleAndDistance(src, netId, maxDistance)
    if type(netId) ~= 'number' or netId <= 0 then
        return false, nil, L('invalid_vehicle')
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return false, nil, L('invalid_vehicle')
    end

    local ped = GetPlayerPed(src)
    if ped <= 0 then
        return false, nil, L('invalid_player')
    end

    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(vehicle)
    if #(pCoords - vCoords) > (maxDistance or Config.MaxServiceDistance) then
        return false, nil, L('too_far')
    end

    return true, vehicle
end

local function cooldownKey(src, action)
    return ('%s:%s'):format(src, action)
end

local function inCooldown(src, action)
    local untilTs = State.cooldowns[cooldownKey(src, action)]
    return untilTs and untilTs > os.time() or false
end

local function setCooldown(src, action, seconds)
    State.cooldowns[cooldownKey(src, action)] = os.time() + (seconds or 1)
end

local function checkAndConsumeItem(src, service)
    if not service.requiresItem then
        return true
    end

    local item = service.requiresItem
    local ok, count = pcall(exports.ox_inventory.Search, exports.ox_inventory, src, 'count', item.name)
    if not ok then
        return false, L('inventory_unavailable')
    end

    if (count or 0) < item.count then
        return false, L('item_missing', item.name, item.count)
    end

    local removed = exports.ox_inventory:RemoveItem(src, item.name, item.count)
    if not removed then
        return false, L('service_failed')
    end

    return true
end

local function clearPlayerServiceLocks(src)
    local netId = State.activeServiceByPlayer[src]
    if netId then
        State.activeServiceByPlayer[src] = nil
        State.activeServicesByVehicle[netId] = nil
    end
end

if Config.EnableStash then
    local stash = Config.Stash
    exports.ox_inventory:RegisterStash(stash.id, stash.label, stash.slots, stash.weight, stash.owner, stash.groups)
end

lib.callback.register('bakitelli_mechanic:server:getState', function(source)
    local ok, _, job = Validators.mechanic(source)
    if not ok then return false, nil end

    local grade = (job.grade and (job.grade.level or job.grade)) or 0

    return true, {
        onDuty = job.onduty == true,
        isBoss = grade >= Config.MinBossGrade,
        hasVehicleOut = State.serviceVehicles[source] ~= nil,
        requireDuty = Config.RequireDuty
    }
end)

RegisterNetEvent('bakitelli_mechanic:server:toggleDuty', function()
    local src = source
    if inCooldown(src, 'duty') then return end

    local ok, player, job, err = Validators.mechanic(src)
    if not ok then
        notify(src, 'error', err)
        log('toggleDuty denied src', tostring(src), err)
        return
    end

    local newDuty = not (job.onduty == true)
    player.Functions.SetJobDuty(newDuty)
    setCooldown(src, 'duty', Config.Cooldowns.duty)
    notify(src, 'success', newDuty and L('duty_on') or L('duty_off'))
end)

lib.callback.register('bakitelli_mechanic:server:canService', function(source, netId, serviceType)
    local service = Config.Services[serviceType]
    if not service then
        return false, L('service_failed')
    end

    local ok, _, _, err = Validators.duty(source)
    if not ok then return false, err end

    if inCooldown(source, 'service_' .. serviceType) then
        return false, L('cooldown_active')
    end

    if State.activeServiceByPlayer[source] then
        return false, L('busy_player')
    end

    local validVehicle, _, vehicleErr = Validators.vehicleAndDistance(source, netId)
    if not validVehicle then
        return false, vehicleErr
    end

    if State.activeServicesByVehicle[netId] then
        return false, L('service_locked')
    end

    return true
end)

lib.callback.register('bakitelli_mechanic:server:performService', function(source, netId, serviceType)
    local service = Config.Services[serviceType]
    if not service then
        return false, L('service_failed')
    end

    local ok, player, _, err = Validators.duty(source)
    if not ok then return false, err end

    if inCooldown(source, 'service_' .. serviceType) then
        return false, L('cooldown_active')
    end

    if State.activeServiceByPlayer[source] then
        return false, L('busy_player')
    end

    local validVehicle, vehicle, vehicleErr = Validators.vehicleAndDistance(source, netId)
    if not validVehicle then
        return false, vehicleErr
    end

    if State.activeServicesByVehicle[netId] then
        return false, L('service_locked')
    end

    State.activeServiceByPlayer[source] = netId
    State.activeServicesByVehicle[netId] = source

    local itemOk, itemErr = checkAndConsumeItem(source, service)
    if not itemOk then
        clearPlayerServiceLocks(source)
        return false, itemErr
    end

    TriggerClientEvent('bakitelli_mechanic:client:applyService', source, netId, serviceType)

    local plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    MySQL.insert.await('INSERT INTO mechanic_service_logs (plate, service_type, mechanic_license) VALUES (?, ?, ?)', {
        plate,
        serviceType,
        player.PlayerData.license
    })

    setCooldown(source, 'service_' .. serviceType, service.cooldown or Config.Cooldowns.service)
    clearPlayerServiceLocks(source)

    return true, L('service_success', service.label)
end)

lib.callback.register('bakitelli_mechanic:server:spawnServiceVehicle', function(source, stationId, model)
    local ok, _, _, err = Validators.duty(source)
    if not ok then return false, err end

    if inCooldown(source, 'service_vehicle') then
        return false, L('cooldown_active')
    end

    if State.serviceVehicles[source] then
        return false, L('service_vehicle_exists')
    end

    if not Config.ServiceVehicles[model] then
        return false, L('invalid_vehicle_model')
    end

    local station = Config.Stations[stationId]
    if not station or not station.garage then
        return false, L('invalid_station')
    end

    local netId = qbx.spawnVehicle({
        model = joaat(model),
        spawnSource = station.garage,
        warp = GetPlayerPed(source)
    })

    State.serviceVehicles[source] = netId
    setCooldown(source, 'service_vehicle', Config.Cooldowns.serviceVehicle)

    if GetResourceState('mri_Qcarkeys') == 'started' then
        exports.mri_Qcarkeys:AssignKeysOnServiceSpawn(source, netId, {
            category = 'service',
            temporary = true,
            reason = 'bakitelli_service_vehicle'
        })
    end

    return true, netId
end)

lib.callback.register('bakitelli_mechanic:server:returnServiceVehicle', function(source, netId)
    local ok, _, _, err = Validators.mechanic(source)
    if not ok then return false, err end

    local current = State.serviceVehicles[source]
    if not current then
        return false, L('service_vehicle_none')
    end

    if type(netId) == 'number' and netId > 0 and current ~= netId then
        return false, L('service_failed')
    end

    local veh = NetworkGetEntityFromNetworkId(current)
    if veh ~= 0 and DoesEntityExist(veh) then
        DeleteEntity(veh)
    end

    State.serviceVehicles[source] = nil
    return true, L('service_vehicle_returned')
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearPlayerServiceLocks(src)

    local netId = State.serviceVehicles[src]
    if netId then
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh ~= 0 and DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
        State.serviceVehicles[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for src, netId in pairs(State.serviceVehicles) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh ~= 0 and DoesEntityExist(veh) then
            DeleteEntity(veh)
        end
        State.serviceVehicles[src] = nil
    end

    State.activeServiceByPlayer = {}
    State.activeServicesByVehicle = {}
    State.cooldowns = {}
end)
