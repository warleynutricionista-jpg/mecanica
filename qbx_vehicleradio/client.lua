local config = lib.loadJson('qbx_vehicleradio.config')
local radioEnabled = not config.disableRadioByDefault

local function isVrsMechanicActive()
    return GetResourceState('vrs_mechanic') == 'started'
end

local function notifyRadioRestriction(reason)
    local messages = {
        no_power = 'O sistema elétrico do veículo não suporta o rádio agora.',
        service_active = 'O rádio foi bloqueado durante o serviço mecânico.',
        vehicle_on_lift = 'O rádio está bloqueado enquanto o veículo estiver no elevador.',
        engine_off = 'Ligue o veículo para usar o rádio.',
    }

    exports.qbx_core:Notify(messages[reason] or 'O estado mecânico atual bloqueou o rádio.', 'error')
end

local function canUseRadio(vehicle, notify)
    if not isVrsMechanicActive() then
        return true
    end

    local ok, allowed, reason = pcall(function()
        return exports.vrs_mechanic:CanUseVehicleRadio(vehicle)
    end)

    if not ok then
        return true
    end

    if allowed == false then
        if notify then
            notifyRadioRestriction(reason)
        end
        return false
    end

    return true
end

local function applyRadioState(currentVehicle, notify)
    if not currentVehicle or currentVehicle == 0 then
        SetUserRadioControlEnabled(true)
        return
    end

    if radioEnabled and not canUseRadio(currentVehicle, notify) then
        radioEnabled = false
    end

    SetUserRadioControlEnabled(radioEnabled)
    if not radioEnabled then
        SetVehRadioStation(currentVehicle, 'OFF')
    end
end

RegisterCommand(config.toggleCommand, function()
    local currentVehicle = cache.vehicle
    if not currentVehicle or currentVehicle == 0 then
        return
    end

    if not radioEnabled and not canUseRadio(currentVehicle, true) then
        applyRadioState(currentVehicle, false)
        return
    end

    radioEnabled = not radioEnabled

    if radioEnabled then
        if not canUseRadio(currentVehicle, true) then
            radioEnabled = false
            applyRadioState(currentVehicle, false)
            return
        end

        exports.qbx_core:Notify(locale('success.vehicle_radio_on'), 'success')
    else
        exports.qbx_core:Notify(locale('error.vehicle_radio_off'), 'error')
    end

    applyRadioState(currentVehicle, false)
end, false)

if config.toggleKey then
    RegisterKeyMapping(config.toggleCommand, 'Toggle Vehicle Radio', 'keyboard', config.toggleKey)
end

lib.onCache('vehicle', function(currentVehicle)
    applyRadioState(currentVehicle, false)
end)

CreateThread(function()
    while true do
        local currentVehicle = cache.vehicle
        if currentVehicle and currentVehicle ~= 0 then
            applyRadioState(currentVehicle, false)
            Wait(1500)
        else
            Wait(3000)
        end
    end
end)
