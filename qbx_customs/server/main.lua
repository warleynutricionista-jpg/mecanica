lib.versionCheck('Qbox-project/qbx_customs')

local access = require 'server.services.access'
local billing = require 'server.services.billing'
local persistence = require 'server.services.persistence'

lib.callback.register('qbx_customs:server:pay', function(source, mod, level)
    local zoneId = lib.callback.await('qbx_customs:client:zone', source)
    if access.isFreeModAllowed(source, zoneId) then
        return true
    end

    return billing.chargeForMod(source, mod, level)
end)

lib.callback.register('qbx_customs:server:repair', function(source, bodyHealth)
    local zoneId = lib.callback.await('qbx_customs:client:zone', source)
    if access.isFreeRepairAllowed(source, zoneId) then
        return true
    end

    return billing.chargeForRepair(source, bodyHealth)
end)

RegisterNetEvent('qbx_customs:server:saveVehicleProps', function(vehicleProps)
    local src = source --[[@as number]]
    if not vehicleProps then
        vehicleProps = lib.callback.await('qbx_customs:client:vehicleProps', src)
    end

    persistence.saveVehicleProps(vehicleProps)
end)
