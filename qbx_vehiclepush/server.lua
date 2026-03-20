local pushCooldowns = {}

local function checkCooldown(source)
    local now = GetGameTimer()
    if pushCooldowns[source] and (now - pushCooldowns[source]) < 300 then
        return false
    end

    pushCooldowns[source] = now
    return true
end

local function canPushWithMechanic(vehicle)
    if GetResourceState('vrs_mechanic') ~= 'started' then
        return true
    end

    local ok, allowed = pcall(function()
        return exports.vrs_mechanic:CanPushVehicle(vehicle)
    end)

    if not ok then
        return true
    end

    return allowed ~= false
end

RegisterNetEvent('qbx_vehiclepush:server:push', function(data)
    if type(data) ~= 'table' or not data.netId then return end
    if not checkCooldown(source) then return end

    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    if data.direction ~= nil and type(data.direction) ~= 'string' then return end
    if not canPushWithMechanic(vehicle) then return end

    Entity(vehicle).state:set('pushVehicle', data.direction, true)
end)
