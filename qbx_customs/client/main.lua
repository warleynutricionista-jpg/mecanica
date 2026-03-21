local dragcam = require 'client.dragcam'
local session = require 'client.session'
local actions = require 'client.actions'
local ui = require 'client.ui'
local vehicle = require 'client.services.vehicle'
local validator = require 'client.services.validator'
local feedback = require 'client.services.feedback'

local startDragCam = dragcam.startDragCam
local stopDragCam = dragcam.stopDragCam

local DISABLED_CONTROLS = { 71, 72, 75, 85, 106 }
local sessionGuardRunning = false

local function disableControlsLoop()
    CreateThread(function()
        while session.isOpen do
            Wait(0)

            for i = 1, #DISABLED_CONTROLS do
                DisableControlAction(0, DISABLED_CONTROLS[i], true)
            end
        end
    end)
end

local function notifyCloseReason(reason)
    if reason == 'driverSeat' then
        feedback.notify(locale('notifications.error.driverSeat'), 'error')
    elseif reason == 'leftVehicle' or reason == 'invalidVehicle' or reason == 'destroyedVehicle' then
        feedback.notify(locale('notifications.error.invalidVehicle'), 'error')
    elseif reason == 'busy' then
        feedback.notify(locale('notifications.error.busy'), 'error')
    end
end

local function closeMenu(saveVehicle, reason)
    if not session.isOpen or session.isClosing then
        ui.ensureClosed()
        return false
    end

    session.markClosing()
    actions.restoreCommitted()
    stopDragCam()
    ui.setCameraActive(false)
    ui.CloseCustomsUI(reason)

    if saveVehicle and vehicle.isValid(session.vehicle) then
        TriggerServerEvent('qbx_customs:server:saveVehicleProps', lib.getVehicleProperties(session.vehicle))
    end

    session.reset()

    if reason then
        notifyCloseReason(reason)
    end

    return true
end

local function ensureSessionOrClose(saveVehicle)
    local ok, reason = validator.ensureActiveSession()
    if ok then
        return true
    end

    closeMenu(saveVehicle, reason)
    return false
end

ui.setCloseHandler(function(reason)
    closeMenu(true, reason)
end)

local function startSessionGuard()
    if sessionGuardRunning then
        return
    end

    sessionGuardRunning = true

    CreateThread(function()
        while session.isOpen do
            Wait(250)

            local ok, reason = validator.ensureActiveSession()
            if not ok then
                closeMenu(reason ~= 'leftVehicle' and reason ~= 'invalidVehicle' and reason ~= 'destroyedVehicle', reason)
                break
            end

            if not ui.isOpen() and not ui.isBusy() then
                closeMenu(true, 'uiDesync')
                break
            end

            if IsPauseMenuActive() then
                closeMenu(true, 'pauseMenu')
                break
            end
        end

        ui.ensureClosed()
        sessionGuardRunning = false
    end)
end

CreateThread(function()
    Wait(0)
    ui.ensureClosed()
end)

lib.callback.register('qbx_customs:client:vehicleProps', function()
    if not ensureSessionOrClose(false) then
        return nil
    end

    return lib.getVehicleProperties(session.vehicle)
end)

lib.onCache('vehicle', function(vehicleEntity)
    if session.isOpen and not vehicleEntity then
        closeMenu(false, 'leftVehicle')
        return
    end

    if not session.isOpen then
        ui.ensureClosed()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    ui.HardResetCustomsUI()

    if session.isOpen then
        stopDragCam()
        ui.setCameraActive(false)
        session.reset()
    end
end)

return function()
    if session.isOpen or session.isClosing or ui.isBusy() or ui.isOpen() then
        notifyCloseReason('busy')
        return false
    end

    local currentVehicle = cache.vehicle
    local canOpen, reason = validator.canOpenCustoms(currentVehicle)
    if not canOpen then
        notifyCloseReason(reason)
        return false
    end

    session.begin(currentVehicle)
    vehicle.set(currentVehicle)
    actions.captureCommittedProps()
    disableControlsLoop()
    startSessionGuard()
    startDragCam(currentVehicle)
    ui.setCameraActive(true)

    local opened, openReason = ui.OpenCustomsUI()
    if not opened then
        stopDragCam()
        ui.setCameraActive(false)
        session.reset()
        ui.HardResetCustomsUI()
        notifyCloseReason(openReason)
        return false
    end

    return true
end
