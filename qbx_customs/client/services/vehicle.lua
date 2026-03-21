local session = require 'client.session'

local vehicle = {}

local function getCurrentVehicle()
    return session.vehicle
end

local function withCurrentVehicle(callback)
    local targetVehicle = getCurrentVehicle()
    if not vehicle.isValid(targetVehicle) then
        return false
    end

    SetVehicleModKit(targetVehicle, 0)
    callback(targetVehicle)
    return true
end

function vehicle.get()
    return getCurrentVehicle()
end

function vehicle.isValid(targetVehicle)
    return targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle)
end

function vehicle.set(targetVehicle)
    session.vehicle = targetVehicle

    if vehicle.isValid(targetVehicle) then
        SetVehicleModKit(targetVehicle, 0)
    end
end

function vehicle.captureCommittedProps()
    return withCurrentVehicle(function(targetVehicle)
        session.committedProps = lib.getVehicleProperties(targetVehicle)

        if not session.originalProps then
            session.originalProps = table.clone(session.committedProps)
        end
    end)
end

function vehicle.restoreProperties(props)
    if not props then
        return false
    end

    return withCurrentVehicle(function(targetVehicle)
        lib.setVehicleProperties(targetVehicle, props)
    end)
end

function vehicle.restoreCommitted()
    local restored = vehicle.restoreProperties(session.committedProps)
    if restored then
        session.clearPreview()
    end

    return restored
end

function vehicle.restoreOriginal()
    if not session.originalProps then
        return false
    end

    local restored = vehicle.restoreProperties(session.originalProps)
    if restored then
        session.committedProps = table.clone(session.originalProps)
        session.clearPreview()
    end

    return restored
end

function vehicle.applyRepairState()
    return withCurrentVehicle(function(targetVehicle)
        local fuelLevel = GetVehicleFuelLevel(targetVehicle)
        local dirtLevel = GetVehicleDirtLevel(targetVehicle)

        SetVehicleBodyHealth(targetVehicle, 1000.0)
        SetVehicleEngineHealth(targetVehicle, 1000.0)
        SetVehiclePetrolTankHealth(targetVehicle, 1000.0)
        SetVehicleFixed(targetVehicle)
        SetVehicleDeformationFixed(targetVehicle)
        SetVehicleUndriveable(targetVehicle, false)
        SetVehicleEngineOn(targetVehicle, true, true, false)
        SetVehicleFuelLevel(targetVehicle, fuelLevel)
        SetVehicleDirtLevel(targetVehicle, dirtLevel)
    end)
end

function vehicle.isDriveable()
    local targetVehicle = getCurrentVehicle()
    return vehicle.isValid(targetVehicle) and not IsEntityDead(targetVehicle)
end

return vehicle
