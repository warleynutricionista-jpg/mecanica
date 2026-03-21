local dragcam = require 'client.dragcam'
local session = require 'client.session'
local actions = require 'client.actions'
local ui = require 'client.ui'
local vehicle = require 'client.services.vehicle'
local validator = require 'client.services.validator'
local feedback = require 'client.services.feedback'

local startDragCam = dragcam.startDragCam
local stopDragCam = dragcam.stopDragCam

local function disableControls()
    CreateThread(function()
        while session.isOpen do
            Wait(0)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 85, true)
            DisableControlAction(0, 106, true)
        end
    end)
end

local function closeMenu(saveVehicle)
    if not session.isOpen or session.isClosing then return end

    session.isClosing = true
    actions.restoreCommitted()
    stopDragCam()
    ui.hide()

    if saveVehicle and vehicle.isValid(session.vehicle) then
        TriggerServerEvent('qbx_customs:server:saveVehicleProps', lib.getVehicleProperties(session.vehicle))
    end

    session.reset()
end

local function ensureSessionOrClose(saveVehicle)
    local ok, reason = validator.ensureActiveSession()
    if ok then
        return true
    end

    if reason == 'driverSeat' then
        feedback.notify(locale('notifications.error.driverSeat'), 'error')
    elseif reason == 'leftVehicle' or reason == 'invalidVehicle' or reason == 'destroyedVehicle' then
        feedback.notify(locale('notifications.error.invalidVehicle'), 'error')
    end

    closeMenu(saveVehicle)
    return false
end

RegisterNUICallback('selectCategory', function(data, cb)
    if ensureSessionOrClose(true) then
        ui.selectCategory(data.categoryId)
    end
    cb(1)
end)

RegisterNUICallback('selectOption', function(data, cb)
    if ensureSessionOrClose(true) then
        ui.selectOption(data.optionId)
    end
    cb(1)
end)

RegisterNUICallback('previewChoice', function(data, cb)
    if ensureSessionOrClose(false) then
        ui.previewChoice(data.optionId, data.choiceId)
    end
    cb(1)
end)

RegisterNUICallback('installChoice', function(data, cb)
    if ensureSessionOrClose(true) then
        ui.installChoice(data.optionId, data.choiceId)
    end
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb(1)
end)

RegisterNUICallback('restorePreview', function(_, cb)
    if ensureSessionOrClose(false) then
        actions.restoreCommitted()
        ui.refresh()
    end
    cb(1)
end)

lib.callback.register('qbx_customs:client:vehicleProps', function()
    if not ensureSessionOrClose(false) then return nil end
    return lib.getVehicleProperties(session.vehicle)
end)

lib.onCache('vehicle', function(vehicleEntity)
    if session.isOpen and not vehicleEntity then
        closeMenu(true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if session.isOpen then
        closeMenu(false)
    else
        SetNuiFocus(false, false)
    end
end)

return function()
    local currentVehicle = cache.vehicle
    local canOpen, reason = validator.canOpenCustoms(currentVehicle)
    if not canOpen then
        if reason == 'destroyedVehicle' or reason == 'invalidVehicle' then
            feedback.notify(locale('notifications.error.invalidVehicle'), 'error')
        end
        return
    end

    session.isOpen = true
    vehicle.set(currentVehicle)
    actions.captureCommittedProps()
    disableControls()
    startDragCam(currentVehicle)
    ui.open()
end
