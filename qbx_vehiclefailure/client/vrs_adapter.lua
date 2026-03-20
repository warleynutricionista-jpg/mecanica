VRSFailureAdapter = VRSFailureAdapter or {}

local fallbackMessages = {
    service_active = 'Este veículo está em serviço mecânico ativo.',
    vehicle_on_lift = 'Este veículo está no elevador e não pode ser manipulado agora.',
    mechanically_disabled = 'O estado mecânico atual impede esta ação.',
}

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
    return Config.EnableVrsMechanicIntegration ~= false and GetResourceState('vrs_mechanic') == 'started'
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

    pcall(function()
        exports.qbx_mechanicjob:SetVehicleStatus(plate, 'engine', engineHealth)
        exports.qbx_mechanicjob:SetVehicleStatus(plate, 'body', bodyHealth)
        exports.qbx_mechanicjob:SetVehicleStatus(plate, 'battery', batteryHealth)
    end)
end
