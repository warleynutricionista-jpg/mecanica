lib.versionCheck('Qbox-project/qbx_customs')

local access = require 'server.services.access'
local billing = require 'server.services.billing'
local persistence = require 'server.services.persistence'

local function resolveZoneId(source)
    local zoneId = lib.callback.await('qbx_customs:client:zone', source)
    if type(zoneId) ~= 'number' then
        return nil
    end

    return zoneId
end

lib.callback.register('qbx_customs:server:pay', function(source, mod, level)
    local zoneId = resolveZoneId(source)
    if access.isFreeModAllowed(source, zoneId) then
        return true
    end

    return billing.chargeForMod(source, mod, level)
end)

lib.callback.register('qbx_customs:server:repair', function(source, bodyHealth)
    local zoneId = resolveZoneId(source)
    if access.isFreeRepairAllowed(source, zoneId) then
        return true
    end

    return billing.chargeForRepair(source, bodyHealth)
end)

RegisterNetEvent('qbx_customs:server:saveVehicleProps', function(vehicleProps)
    local src = source --[[@as number]]

    if type(vehicleProps) ~= 'table' then
        vehicleProps = lib.callback.await('qbx_customs:client:vehicleProps', src)
    end

    persistence.saveVehicleProps(src, vehicleProps)
end)
