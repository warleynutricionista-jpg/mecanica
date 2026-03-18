-- ============================================================
-- VRS_MECHANIC - VALIDAÇÃO CONTEXTUAL DE SERVIÇOS
-- ============================================================

VRS.ActiveServices = VRS.ActiveServices or {}

local function getServiceConfig(serviceType, serviceKey)
    return Config.ServiceContexts and Config.ServiceContexts[serviceType] and Config.ServiceContexts[serviceType][serviceKey] or nil
end

local function getActiveServiceKey(plate, netId)
    if plate and plate ~= '' then
        return ('plate:%s'):format(plate)
    end

    return ('net:%s'):format(netId or 'unknown')
end

function VRS.FindLiftByVehicle(plate, netId)
    for key, state in pairs(VRS.LiftStates or {}) do
        if state and state.vehicleNetId and ((netId and state.vehicleNetId == netId) or (plate and state.plate == plate)) then
            return key, state
        end
    end

    return nil, nil
end

function VRS.ValidateServiceContext(source, serviceType, serviceKey, data)
    data = data or {}
    local context = getServiceConfig(serviceType, serviceKey)
    if not context then
        return false, 'invalid_service'
    end

    local validVehicle, vehicle, vehicleReason = VRS.ValidateVehicleContext(source, data.plate, data.netId, Config.Lift.maxDistance or 12.0)
    if not validVehicle or not vehicle then
        return false, vehicleReason or 'invalid_vehicle'
    end

    if GetEntitySpeed(vehicle) > 0.5 then
        return false, 'vehicle_moving'
    end

    if context.requiresLift then
        local _, liftState = VRS.FindLiftByVehicle(data.plate, data.netId)
        if not liftState then
            return false, 'lift_required'
        end

        local currentHeight = liftState.height or 0.0
        if currentHeight + 0.01 < (context.minimumLiftHeight or 0.0) then
            return false, 'lift_too_low'
        end
    end

    return true, nil, context
end

lib.callback.register('vrs_mechanic:server:beginVehicleService', function(source, serviceType, serviceKey, data)
    local ok, reason = VRS.ValidateServiceContext(source, serviceType, serviceKey, data)
    if not ok then
        return { success = false, reason = reason }
    end

    local lockKey = getActiveServiceKey(data and data.plate, data and data.netId)
    local active = VRS.ActiveServices[lockKey]
    if active and active.source ~= source then
        return { success = false, reason = 'service_busy' }
    end

    VRS.ActiveServices[lockKey] = {
        source = source,
        serviceType = serviceType,
        serviceKey = serviceKey,
        startedAt = os.time(),
    }

    return { success = true, lockKey = lockKey }
end)

lib.callback.register('vrs_mechanic:server:endVehicleService', function(source, lockKey)
    local active = lockKey and VRS.ActiveServices[lockKey]
    if active and active.source == source then
        VRS.ActiveServices[lockKey] = nil
    end

    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    for lockKey, active in pairs(VRS.ActiveServices) do
        if active and active.source == src then
            VRS.ActiveServices[lockKey] = nil
        end
    end
end)
