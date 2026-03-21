local session = require 'client.session'

local vehicle = {}

local function currentVehicle()
    return session.vehicle
end

local function ensureModKit(targetVehicle)
    if targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) then
        SetVehicleModKit(targetVehicle, 0)
    end
end

local function withVehicle(callback)
    local targetVehicle = currentVehicle()
    if not vehicle.isValid(targetVehicle) then
        return false
    end

    ensureModKit(targetVehicle)
    callback(targetVehicle)
    return true
end

function vehicle.isValid(targetVehicle)
    return targetVehicle and targetVehicle ~= 0 and DoesEntityExist(targetVehicle) and IsEntityAVehicle(targetVehicle)
end

function vehicle.get()
    return currentVehicle()
end

function vehicle.set(targetVehicle)
    session.vehicle = targetVehicle
    session.vehicleNetId = vehicle.isValid(targetVehicle) and NetworkGetNetworkIdFromEntity(targetVehicle) or 0
    ensureModKit(targetVehicle)
end

function vehicle.getPlate(targetVehicle)
    local plate = GetVehicleNumberPlateText(targetVehicle or currentVehicle())
    if not plate then
        return nil
    end

    return (plate:gsub('^%s*(.-)%s*$', '%1'))
end

function vehicle.captureCommitted()
    return withVehicle(function(targetVehicle)
        local props = lib.getVehicleProperties(targetVehicle)
        session.committedProps = props
        if not session.originalProps then
            session.originalProps = table.clone(props)
        end
    end)
end

function vehicle.restoreProperties(props)
    if type(props) ~= 'table' then
        return false
    end

    return withVehicle(function(targetVehicle)
        lib.setVehicleProperties(targetVehicle, props)
        ensureModKit(targetVehicle)
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
    local restored = vehicle.restoreProperties(session.originalProps)
    if restored then
        session.committedProps = session.originalProps and table.clone(session.originalProps) or nil
        session.clearPreview()
    end
    return restored
end

function vehicle.getProps()
    local targetVehicle = currentVehicle()
    if not vehicle.isValid(targetVehicle) then
        return nil
    end

    ensureModKit(targetVehicle)
    return lib.getVehicleProperties(targetVehicle)
end

function vehicle.applyRepairPreview()
    return withVehicle(function(targetVehicle)
        local fuelLevel = GetVehicleFuelLevel(targetVehicle)
        local dirtLevel = GetVehicleDirtLevel(targetVehicle)

        SetVehicleFixed(targetVehicle)
        SetVehicleDeformationFixed(targetVehicle)
        SetVehicleUndriveable(targetVehicle, false)
        SetVehicleEngineOn(targetVehicle, true, true, false)
        SetVehicleBodyHealth(targetVehicle, 1000.0)
        SetVehicleEngineHealth(targetVehicle, 1000.0)
        SetVehiclePetrolTankHealth(targetVehicle, 1000.0)
        SetVehicleFuelLevel(targetVehicle, fuelLevel)
        SetVehicleDirtLevel(targetVehicle, dirtLevel)
    end)
end

function vehicle.isDriver(targetVehicle)
    targetVehicle = targetVehicle or currentVehicle()
    return vehicle.isValid(targetVehicle) and GetPedInVehicleSeat(targetVehicle, -1) == cache.ped
end

function vehicle.isDestroyed(targetVehicle)
    targetVehicle = targetVehicle or currentVehicle()
    return not vehicle.isValid(targetVehicle) or IsEntityDead(targetVehicle)
end

return vehicle
