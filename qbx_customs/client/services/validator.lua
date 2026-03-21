local session = require 'client.session'
local vehicle = require 'client.services.vehicle'

local validator = {}

function validator.canOpenCustoms(targetVehicle)
    if session.isOpen or session.isClosing then
        return false, 'busy'
    end

    if not vehicle.isValid(targetVehicle) then
        return false, 'invalidVehicle'
    end

    if IsEntityDead(targetVehicle) then
        return false, 'destroyedVehicle'
    end

    return true
end

function validator.ensureActiveSession()
    local targetVehicle = vehicle.get()
    if not session.isOpen then
        return false, 'closed'
    end

    if not vehicle.isValid(targetVehicle) then
        return false, 'invalidVehicle'
    end

    if IsEntityDead(targetVehicle) then
        return false, 'destroyedVehicle'
    end

    if cache.vehicle ~= targetVehicle then
        return false, 'leftVehicle'
    end

    if GetPedInVehicleSeat(targetVehicle, -1) ~= cache.ped then
        return false, 'driverSeat'
    end

    return true
end

return validator
