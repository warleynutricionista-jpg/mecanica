local session = require 'client.session'

local vehicle = {}

local function getCurrentVehicle()
    return session.vehicle
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
    local targetVehicle = getCurrentVehicle()
    if not vehicle.isValid(targetVehicle) then return false end

    session.committedProps = lib.getVehicleProperties(targetVehicle)
    if not session.originalProps then
        session.originalProps = table.clone(session.committedProps)
    end

    return true
end

function vehicle.restoreProperties(props)
    local targetVehicle = getCurrentVehicle()
    if not props or not vehicle.isValid(targetVehicle) then return false end

    lib.setVehicleProperties(targetVehicle, props)
    SetVehicleModKit(targetVehicle, 0)
    return true
end

function vehicle.restoreCommitted()
    local restored = vehicle.restoreProperties(session.committedProps)
    if restored then
        session.previewOption = nil
        session.previewChoice = nil
    end

    return restored
end

function vehicle.restoreOriginal()
    if not session.originalProps then return false end
    local restored = vehicle.restoreProperties(session.originalProps)
    if restored then
        session.committedProps = table.clone(session.originalProps)
        session.previewOption = nil
        session.previewChoice = nil
    end

    return restored
end

function vehicle.applyRepairState()
    local targetVehicle = getCurrentVehicle()
    if not vehicle.isValid(targetVehicle) then return false end

    local fuelLevel = GetVehicleFuelLevel(targetVehicle)
    SetVehicleBodyHealth(targetVehicle, 1000.0)
    SetVehicleEngineHealth(targetVehicle, 1000.0)
    SetVehicleFixed(targetVehicle)
    SetVehicleFuelLevel(targetVehicle, fuelLevel)
    return true
end

function vehicle.isDriveable()
    local targetVehicle = getCurrentVehicle()
    return vehicle.isValid(targetVehicle) and not IsEntityDead(targetVehicle)
end

return vehicle
