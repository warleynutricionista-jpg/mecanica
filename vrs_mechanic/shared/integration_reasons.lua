VRS = VRS or {}

VRS.IntegrationReasonMessages = VRS.IntegrationReasonMessages or {
    generic = {
        invalid_vehicle = 'Entidade de veículo inválida.',
        service_active = 'Este veículo está em serviço mecânico ativo.',
        vehicle_on_lift = 'Este veículo está no elevador.',
        mechanically_disabled = 'O estado mecânico atual impede esta ação.',
        no_power = 'O sistema elétrico do veículo não suporta esta ação agora.',
        engine_off = 'Ligue o veículo para usar este sistema.',
        mechanic_blocked = 'A integração mecânica bloqueou esta ação no momento.',
    },
    actions = {
        lockpick = {
            service_active = 'Este veículo está em serviço mecânico e não pode ser arrombado agora.',
            vehicle_on_lift = 'Este veículo está no elevador e o lockpick foi bloqueado.',
        },
        push = {
            service_active = 'Este veículo está em serviço mecânico e não pode ser empurrado.',
            vehicle_on_lift = 'Este veículo está no elevador e não pode ser empurrado.',
            mechanically_disabled = 'O estado mecânico atual bloqueia o empurrão.',
        },
        radio = {
            no_power = 'O sistema elétrico do veículo não suporta o rádio agora.',
            service_active = 'O rádio foi bloqueado durante o serviço mecânico.',
            vehicle_on_lift = 'O rádio está bloqueado enquanto o veículo estiver no elevador.',
            engine_off = 'Ligue o veículo para usar o rádio.',
        },
        repair = {
            service_active = 'Este veículo está em serviço mecânico ativo.',
            vehicle_on_lift = 'Este veículo está no elevador e não pode ser manipulado agora.',
            mechanically_disabled = 'O estado mecânico atual impede esta ação.',
        },
        garage = {
            service_active = 'O veículo não pode ser guardado durante um serviço mecânico.',
            vehicle_on_lift = 'O veículo não pode ser guardado enquanto estiver no elevador.',
        },
    }
}

function VRS.GetIntegrationReasonMessage(reason, action)
    local actionMessages = action and VRS.IntegrationReasonMessages.actions[action] or nil
    if actionMessages and actionMessages[reason] then
        return actionMessages[reason]
    end

    return VRS.IntegrationReasonMessages.generic[reason] or VRS.IntegrationReasonMessages.generic.mechanic_blocked
end
