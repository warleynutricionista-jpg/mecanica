local session = require 'client.session'
local vehicle = require 'client.services.vehicle'

local validator = {}

local function isDriver(targetVehicle)
    return targetVehicle ~= 0 and GetPedInVehicleSeat(targetVehicle, -1) == cache.ped
end

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

    if not isDriver(targetVehicle) then
        return false, 'driverSeat'
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

    if not isDriver(targetVehicle) then
        return false, 'driverSeat'
    end

    return true
end

function validator.isRenderableChoice(option, choice)
    return option and choice and not choice.blocked and type(choice.apply) == 'function'
end

return validator
