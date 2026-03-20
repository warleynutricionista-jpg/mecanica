-- ============================================================
-- VRS_MECHANIC - BRIDGE SERVER DE COMPATIBILIDADE
-- ============================================================

VRS = VRS or {}

local function isVehicleEntity(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle)
end

local function resolveVehicle(vehicleOrPlate)
    if type(vehicleOrPlate) == 'number' then
        if isVehicleEntity(vehicleOrPlate) then
            return vehicleOrPlate, VRS.GetPlate(vehicleOrPlate)
        end

        local entity = VRS.GetEntityFromNetId and VRS.GetEntityFromNetId(vehicleOrPlate, true) or nil
        if isVehicleEntity(entity) then
            return entity, VRS.GetPlate(entity)
        end

        return nil, nil
    end

    if type(vehicleOrPlate) == 'string' then
        return nil, vehicleOrPlate
    end

    return nil, nil
end

---@param vehicleOrPlate number|string
---@return table
function VRS.GetIntegratedVehicleStateServer(vehicleOrPlate)
    local vehicle, plate = resolveVehicle(vehicleOrPlate)
    local status = plate and exports[GetCurrentResourceName()]:GetVehicleStatus(plate) or nil
    local liftState = nil
    if VRS.FindLiftByVehicle then
        local _foundLiftKey
        local vehicleNetId = vehicle and VRS.GetSafeNetId and select(1, VRS.GetSafeNetId(vehicle)) or nil
        _foundLiftKey, liftState = VRS.FindLiftByVehicle(plate, vehicleNetId)
    end

    local serviceState = nil
    local lockCandidates = {}
    if plate then
        lockCandidates[#lockCandidates + 1] = 'plate:' .. plate
    end
    if vehicle then
        local netId = VRS.GetSafeNetId and select(1, VRS.GetSafeNetId(vehicle)) or nil
        if netId then
            lockCandidates[#lockCandidates + 1] = 'net:' .. tostring(netId)
        end
    end
    for _, key in ipairs(lockCandidates) do
        local active = VRS.ActiveServices and VRS.ActiveServices[key] or nil
        if active then
            serviceState = active
            break
        end
    end

    local integration = Config.VehicleIntegration or {}
    local battery = status and status.battery or Config.MaxStatus.battery
    local engine = status and status.engine or (vehicle and GetVehicleEngineHealth(vehicle) or nil)

    return {
        exists = plate ~= nil,
        vehicle = vehicle,
        plate = plate,
        status = status,
        onLift = liftState ~= nil,
        lift = liftState,
        inService = serviceState ~= nil,
        service = serviceState,
        disabledByMechanic = VRS.HasCriticalMechanicalFailure(status),
        engineHealth = engine,
        batteryHealth = battery,
        powered = (battery or 0) > (integration.CriticalBatteryThreshold or 5.0),
    }
end

function VRS.IsVehicleUnderMechanicServiceServer(vehicleOrPlate)
    local state = VRS.GetIntegratedVehicleStateServer(vehicleOrPlate)
    return state.inService == true, state
end

function VRS.IsVehicleOnLiftServer(vehicleOrPlate)
    local state = VRS.GetIntegratedVehicleStateServer(vehicleOrPlate)
    return state.onLift == true, state
end


function VRS.CanPushVehicleServer(vehicleOrPlate)
    local state = VRS.GetIntegratedVehicleStateServer(vehicleOrPlate)
    if not state.exists then
        return false, 'invalid_vehicle', state
    end

    local integration = Config.VehicleIntegration or {}
    if integration.BlockPushWhenOnLift ~= false and state.onLift then
        return false, 'vehicle_on_lift', state
    end

    if integration.BlockPushDuringService ~= false and state.inService then
        return false, 'service_active', state
    end

    if integration.BlockPushWhenDisabledByMechanic ~= false and state.disabledByMechanic then
        return false, 'mechanically_disabled', state
    end

    return true, nil, state
end

function VRS.CanStoreVehicleServer(vehicle, options)
    local state = VRS.GetIntegratedVehicleStateServer(vehicle)
    if not state.exists then
        return true, nil, state
    end

    local integration = Config.VehicleIntegration or {}
    if integration.RespectMechanicGarageRestrictions == false then
        return true, nil, state
    end

    if state.inService then
        return false, 'service_active', state
    end

    if state.onLift then
        return false, 'vehicle_on_lift', state
    end

    return true, nil, state
end

function VRS.GetVehiclePersistenceData(plate)
    if not plate then return nil end

    local state = VRS.GetIntegratedVehicleStateServer(plate)
    return {
        status = state.status and VRS.DeepCopy(state.status) or nil,
        savedAt = os.time(),
    }
end

exports('GetIntegratedVehicleState', VRS.GetIntegratedVehicleStateServer)
exports('IsVehicleUnderMechanicService', VRS.IsVehicleUnderMechanicServiceServer)
exports('IsVehicleOnLift', VRS.IsVehicleOnLiftServer)
exports('CanPushVehicle', VRS.CanPushVehicleServer)
exports('CanStoreVehicle', VRS.CanStoreVehicleServer)
exports('GetVehiclePersistenceData', VRS.GetVehiclePersistenceData)

exports('GetIntegrationReasonMessage', function(action, reason)
    return VRS.GetIntegrationReasonMessage(reason, action)
end)
