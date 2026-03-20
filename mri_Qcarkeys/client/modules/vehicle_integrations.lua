local VehicleIntegrations = {}

local fallbackReasons = {
    generic = {
        invalid_vehicle = 'Entidade de veículo inválida.',
        service_active = 'Este veículo está em serviço mecânico ativo.',
        vehicle_on_lift = 'Este veículo está no elevador.',
        mechanically_disabled = 'O estado mecânico atual impede esta ação.',
        mechanic_blocked = 'A integração mecânica bloqueou esta ação no momento.'
    },
    actions = {
        lockpick = {
            service_active = 'Este veículo está em serviço mecânico e não pode ser arrombado agora.',
            vehicle_on_lift = 'Este veículo está no elevador e o lockpick foi bloqueado.'
        },
        ignition = {
            service_active = 'Este veículo está em serviço mecânico e não pode ser ligado agora.',
            vehicle_on_lift = 'Este veículo está no elevador e não pode ser ligado agora.',
            mechanically_disabled = 'O estado mecânico atual impede ligar este veículo.'
        }
    }
}

function VehicleIntegrations:IsResourceStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

function VehicleIntegrations:IsVrsMechanicActive()
    return self:IsResourceStarted('vrs_mechanic')
end

function VehicleIntegrations:GetReasonMessage(action, reason)
    if self:IsVrsMechanicActive() then
        local ok, message = pcall(function()
            return exports.vrs_mechanic:GetIntegrationReasonMessage(action, reason)
        end)

        if ok and type(message) == 'string' and message ~= '' then
            return message
        end
    end

    local actionMessages = fallbackReasons.actions[action]
    return actionMessages and actionMessages[reason]
        or fallbackReasons.generic[reason]
        or fallbackReasons.generic.mechanic_blocked
end

function VehicleIntegrations:NotifyBlocked(action, reason)
    lib.notify({
        description = self:GetReasonMessage(action, reason),
        type = 'error'
    })
end

function VehicleIntegrations:CanLockpick(vehicle, notify)
    if not self:IsVrsMechanicActive() then
        return true
    end

    local ok, allowed, reason = pcall(function()
        return exports.vrs_mechanic:CanLockpickVehicle(vehicle)
    end)

    if not ok or allowed ~= false then
        return true
    end

    if notify then
        self:NotifyBlocked('lockpick', reason)
    end

    return false, reason
end

function VehicleIntegrations:CanUseIgnition(vehicle, notify)
    if not self:IsVrsMechanicActive() then
        return true
    end

    local ok, allowed, reason = pcall(function()
        return exports.vrs_mechanic:CanUseVehicleWithMechanic(vehicle)
    end)

    if not ok or allowed ~= false then
        return true
    end

    if notify then
        self:NotifyBlocked('ignition', reason)
    end

    return false, reason
end

return VehicleIntegrations
