VRSFailureAdapter = VRSFailureAdapter or {}

local fallbackMessages = {
    service_active = 'Este veículo está em serviço mecânico ativo.',
    vehicle_on_lift = 'Este veículo está no elevador e não pode ser manipulado agora.',
    mechanically_disabled = 'O estado mecânico atual impede esta ação.',
}

local function isResourceStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

local function hasLegacyMechanicBridge()
    return isResourceStarted('qbx_mechanicjob') or isResourceStarted('qb-mechanicjob')
end

local function getReasonMessage(reason)
    if GetResourceState('vrs_mechanic') ~= 'started' then
        return fallbackMessages[reason] or 'A integração mecânica bloqueou esta ação no momento.'
    end

    local ok, message = pcall(function()
        return exports.vrs_mechanic:GetIntegrationReasonMessage('repair', reason)
    end)

    return ok and message or fallbackMessages[reason] or 'A integração mecânica bloqueou esta ação no momento.'
end

function VRSFailureAdapter.IsActive()
    return Config.EnableVrsMechanicIntegration ~= false and isResourceStarted('vrs_mechanic')
end

function VRSFailureAdapter.GetIntegrationMode()
    return Config.VrsIntegrationMode or 'mechanic-driven'
end

function VRSFailureAdapter.IsMechanicDrivenMode()
    return VRSFailureAdapter.IsActive() and VRSFailureAdapter.GetIntegrationMode() == 'mechanic-driven'
end

function VRSFailureAdapter.GetMechanicBridgeState(vehicle)
    if not VRSFailureAdapter.IsActive() or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local ok, state = pcall(function()
        return exports.vrs_mechanic:GetIntegratedVehicleState(vehicle)
    end)

    return ok and state or nil
end

function VRSFailureAdapter.GetVehiclePartStatus(plate, part)
    if not plate or plate == '' or not part then return nil end

    if VRSFailureAdapter.IsActive() then
        local ok, value = pcall(function()
            return exports.vrs_mechanic:GetVehicleStatus(plate, part)
        end)

        if ok then
            return value
        end
    end

    if hasLegacyMechanicBridge() then
        local ok, value = pcall(function()
            return exports.qbx_mechanicjob:GetVehicleStatus(plate, part)
        end)

        if ok then
            return value
        end
    end

    return nil
end

function VRSFailureAdapter.SetVehiclePartStatus(plate, part, value)
    if not plate or plate == '' or not part or value == nil then return false end

    if VRSFailureAdapter.IsActive() then
        local ok = pcall(function()
            exports.vrs_mechanic:SetVehicleStatus(plate, part, value)
        end)

        if ok then
            return true
        end
    end

    if hasLegacyMechanicBridge() then
        local ok = pcall(function()
            exports.qbx_mechanicjob:SetVehicleStatus(plate, part, value)
        end)

        if ok then
            return true
        end
    end

    return false
end

function VRSFailureAdapter.ApplyRandomComponentDamage(plate, part, amount)
    if not plate or plate == '' or not part or not amount then return false end

    local currentValue = tonumber(VRSFailureAdapter.GetVehiclePartStatus(plate, part)) or 0
    return VRSFailureAdapter.SetVehiclePartStatus(plate, part, currentValue - amount)
end

function VRSFailureAdapter.NotifyMechanicRestriction(reason)
    exports.qbx_core:Notify(getReasonMessage(reason), 'error')
end

function VRSFailureAdapter.CanUseRepairFlow(vehicle)
    if not VRSFailureAdapter.IsActive() or Config.BlockRepairKitDuringMechanicService == false then
        return true
    end

    local state = VRSFailureAdapter.GetMechanicBridgeState(vehicle)
    if not state then return true end

    if state.inService then
        VRSFailureAdapter.NotifyMechanicRestriction('service_active')
        return false
    end

    if state.onLift then
        VRSFailureAdapter.NotifyMechanicRestriction('vehicle_on_lift')
        return false
    end

    return true
end

function VRSFailureAdapter.SyncMechanicRepairState(vehicle, engineHealth)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local plate = qbx.getVehiclePlate(vehicle)
    if not plate or plate == '' then return end

    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local batteryHealth = engineHealth >= 1000 and 100.0 or 50.0

    VRSFailureAdapter.SetVehiclePartStatus(plate, 'engine', engineHealth)
    VRSFailureAdapter.SetVehiclePartStatus(plate, 'body', bodyHealth)
    VRSFailureAdapter.SetVehiclePartStatus(plate, 'battery', batteryHealth)
end
