-- ============================================================
-- VRS_MECHANIC - BRIDGE CLIENT DE COMPATIBILIDADE
-- ============================================================

VRS = VRS or {}

local function isVehicleEntity(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle)
end

local function getServiceState(vehicle, plate)
    if not isVehicleEntity(vehicle) then return nil end

    local entityState = Entity(vehicle).state
    local serviceState = entityState and entityState['vrs:service'] or nil
    if serviceState then
        return serviceState
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local activeServices = LocalPlayer.state.vrsActiveServices or {}

    if plate and activeServices['plate:' .. plate] then
        return activeServices['plate:' .. plate]
    end

    if activeServices['net:' .. tostring(netId)] then
        return activeServices['net:' .. tostring(netId)]
    end

    return nil
end

---@param vehicle number
---@return table
function VRS.GetIntegratedVehicleState(vehicle)
    if not isVehicleEntity(vehicle) then
        return {
            exists = false,
            reason = 'invalid_vehicle',
        }
    end

    local plate = VRS.GetPlate(vehicle)
    local status = plate and VRS.GetLocalStatus(plate) or nil
    local liftState, liftKey = VRS.GetLiftStateForVehicle(vehicle)
    local entityLiftState = Entity(vehicle).state and Entity(vehicle).state['vrs:onLift'] or nil
    local serviceState = getServiceState(vehicle, plate)
    local integration = Config.VehicleIntegration or {}
    local battery = status and status.battery or Config.MaxStatus.battery
    local engine = status and status.engine or GetVehicleEngineHealth(vehicle)
    local powered = (battery or 0) > (integration.CriticalBatteryThreshold or 5.0)
    local disabled = VRS.HasCriticalMechanicalFailure(status)
    if not liftState and entityLiftState then
        liftState = entityLiftState
        liftKey = entityLiftState.shopId and entityLiftState.liftIndex and ('%s_%s'):format(entityLiftState.shopId, entityLiftState.liftIndex) or nil
    end

    local onLift = liftState ~= nil
    local inService = serviceState ~= nil
    local engineRunning = GetIsVehicleEngineRunning(vehicle)

    return {
        exists = true,
        plate = plate,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        status = status,
        service = serviceState,
        inService = inService,
        serviceType = serviceState and serviceState.serviceType or nil,
        serviceKey = serviceState and serviceState.serviceKey or nil,
        onLift = onLift,
        lift = liftState,
        liftKey = liftKey,
        powered = powered,
        engineHealth = engine,
        batteryHealth = battery,
        engineRunning = engineRunning,
        disabledByMechanic = disabled,
        canStartEngine = (not inService) and (not onLift) and (not disabled),
    }
end

---@param module string
---@param vehicle number
---@param fallbackReason string|nil
---@return boolean, string|nil, table
local function withIntegratedState(module, vehicle, fallbackReason)
    local state = VRS.GetIntegratedVehicleState(vehicle)
    if not state.exists then
        return false, fallbackReason or state.reason, state
    end
    return true, nil, state
end

---@param vehicle number
---@return boolean, string|nil, table
function VRS.CanLockpickVehicle(vehicle)
    local ok, reason, state = withIntegratedState('lockpick', vehicle)
    if not ok then
        return false, reason, state
    end

    local integration = Config.VehicleIntegration or {}
    if integration.BlockLockpickDuringService ~= false and state.inService then
        return false, 'service_active', state
    end

    if integration.BlockLockpickWhenOnLift ~= false and state.onLift then
        return false, 'vehicle_on_lift', state
    end

    return true, nil, state
end

---@param vehicle number
---@return boolean, string|nil, table
function VRS.CanPushVehicle(vehicle)
    local ok, reason, state = withIntegratedState('push', vehicle)
    if not ok then
        return false, reason, state
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

---@param vehicle number
---@return boolean, string|nil, table
function VRS.CanUseVehicleRadio(vehicle)
    local ok, reason, state = withIntegratedState('radio', vehicle)
    if not ok then
        return false, reason, state
    end

    local integration = Config.VehicleIntegration or {}
    if integration.RespectMechanicRadioState == false then
        return true, nil, state
    end

    if not integration.AllowRadioOnLift and state.onLift then
        return false, 'vehicle_on_lift', state
    end

    if not integration.AllowRadioDuringService and state.inService then
        return false, 'service_active', state
    end

    if not state.powered then
        return false, 'no_power', state
    end

    if not integration.AllowRadioWithoutEngine and not state.engineRunning then
        return false, 'engine_off', state
    end

    return true, nil, state
end

---@param vehicle number
---@return boolean, string|nil, table
function VRS.CanUseVehicleWithMechanic(vehicle)
    local ok, reason, state = withIntegratedState('bridge', vehicle)
    if not ok then
        return false, reason, state
    end

    if state.inService then
        return false, 'service_active', state
    end

    if state.onLift then
        return false, 'vehicle_on_lift', state
    end

    if state.disabledByMechanic and (Config.VehicleIntegration or {}).RespectMechanicIgnitionState ~= false then
        return false, 'mechanically_disabled', state
    end

    return true, nil, state
end

function VRS.IsVehicleUnderMechanicService(vehicle)
    local _, _, state = withIntegratedState('bridge', vehicle)
    return state and state.inService == true or false, state
end

function VRS.IsVehicleOnLift(vehicle)
    local _, _, state = withIntegratedState('bridge', vehicle)
    return state and state.onLift == true or false, state
end

function VRS.IsVehicleDisabledByMechanic(vehicle)
    local _, _, state = withIntegratedState('bridge', vehicle)
    return state and state.disabledByMechanic == true or false, state
end

exports('GetIntegratedVehicleState', VRS.GetIntegratedVehicleState)
exports('CanUseVehicleWithMechanic', VRS.CanUseVehicleWithMechanic)
exports('IsVehicleUnderMechanicService', VRS.IsVehicleUnderMechanicService)
exports('IsVehicleOnLift', VRS.IsVehicleOnLift)
exports('CanPushVehicle', VRS.CanPushVehicle)
exports('CanLockpickVehicle', VRS.CanLockpickVehicle)
exports('CanUseVehicleRadio', VRS.CanUseVehicleRadio)
exports('IsVehicleDisabledByMechanic', VRS.IsVehicleDisabledByMechanic)

exports('GetIntegrationReasonMessage', function(action, reason)
    return VRS.GetIntegrationReasonMessage(reason, action)
end)
