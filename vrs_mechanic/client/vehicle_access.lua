-- ============================================================
-- VRS_MECHANIC - ACESSO A PARTES DO VEÍCULO
-- ============================================================

local doorIndexes = {
    hood = 4,
    trunk = 5,
    front_left = 0,
    front_right = 1,
    rear_left = 2,
    rear_right = 3,
}

local function setDoorState(vehicle, doorName, open)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local index = doorIndexes[doorName]
    if index == nil then return end

    if open then
        SetVehicleDoorOpen(vehicle, index, false, false)
    else
        SetVehicleDoorShut(vehicle, index, false)
    end
end

function VRS.OpenVehicleAccess(vehicle, context)
    if not context or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if context.requiresHoodOpen then
        setDoorState(vehicle, 'hood', true)
    end

    if context.requiresTrunkOpen then
        setDoorState(vehicle, 'trunk', true)
    end

    if context.requiresDoorOpen then
        setDoorState(vehicle, context.requiresDoorOpen, true)
    end
end

function VRS.CloseVehicleAccess(vehicle, context)
    if not context or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if context.requiresHoodOpen then
        setDoorState(vehicle, 'hood', false)
    end

    if context.requiresTrunkOpen then
        setDoorState(vehicle, 'trunk', false)
    end

    if context.requiresDoorOpen then
        setDoorState(vehicle, context.requiresDoorOpen, false)
    end
end
