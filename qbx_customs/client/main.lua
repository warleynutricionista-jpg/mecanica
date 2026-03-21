local session = require 'client.session'
local camera = require 'client.camera'
local menu = require 'client.menu'
local access = require 'client.services.access'
local vehicleService = require 'client.services.vehicle'
local feedback = require 'client.services.feedback'

local DISABLED_CONTROLS = { 71, 72, 75, 85, 106 }
local guardRunning = false

local cancelPreview
local applyChoice

local function notifyReason(reason)
    local messages = {
        busy = locale('notifications.error.busy'),
        notDriver = locale('notifications.error.driverSeat'),
        invalidVehicle = locale('notifications.error.invalidVehicle'),
        destroyedVehicle = locale('notifications.error.invalidVehicle'),
        notPersisted = locale('notifications.error.notPersisted'),
        noSession = locale('notifications.error.sessionMissing'),
        paymentFailed = locale('notifications.error.money'),
        saveFailed = locale('notifications.error.saveFailed'),
        accessDenied = locale('notifications.error.noAccess'),
        zoneInvalid = locale('notifications.error.noAccess'),
        invalidPlate = locale('notifications.error.saveFailed'),
        invalidProps = locale('notifications.error.saveFailed'),
    }

    if messages[reason] then
        feedback.notify(messages[reason], 'error')
    end
end

local function isSessionVehicleValid()
    if not session.isOpen then
        return false, 'noSession'
    end

    local vehicle = vehicleService.get()
    if not vehicleService.isValid(vehicle) then
        return false, 'invalidVehicle'
    end

    if vehicleService.isDestroyed(vehicle) then
        return false, 'destroyedVehicle'
    end

    if cache.vehicle ~= vehicle then
        return false, 'invalidVehicle'
    end

    if not vehicleService.isDriver(vehicle) then
        return false, 'notDriver'
    end

    return true
end

local function closeSession(reason, restoreCommitted)
    if not session.isOpen then
        menu.close()
        camera.stop()
        return
    end

    if session.isClosing then
        return
    end

    session.markClosing()
    if restoreCommitted ~= false then
        vehicleService.restoreCommitted()
    end

    camera.stop()
    menu.close()
    TriggerServerEvent('qbx_customs:server:closeSession')
    session.reset()

    if reason and reason ~= 'closeAction' and reason ~= 'contextClosed' then
        notifyReason(reason)
    end
end

local function previewChoice(option, choice)
    if choice.blocked then
        return
    end

    if choice.installed then
        session.setSelection(nil, option.id, choice.id)
        menu.refresh(previewChoice, applyChoice, cancelPreview, 'qbx_customs:choices')
        return
    end

    vehicleService.restoreCommitted()
    local ok, err = pcall(choice.preview)
    if not ok then
        vehicleService.restoreCommitted()
        feedback.notify(locale('notifications.error.applyFailed'), 'error')
        lib.print.error(('[qbx_customs] preview failed for %s: %s'):format(choice.id, err))
        return
    end

    session.setSelection(nil, option.id, choice.id)
    session.setPreview({ optionId = option.id, choiceId = choice.id })
    menu.refresh(previewChoice, applyChoice, cancelPreview, 'qbx_customs:choices')
end

cancelPreview = function()
    vehicleService.restoreCommitted()
    session.clearPreview()
    menu.refresh(previewChoice, applyChoice, cancelPreview, 'qbx_customs:choices')
end

applyChoice = function(option, choice)
    local ok, reason = isSessionVehicleValid()
    if not ok then
        closeSession(reason, true)
        return
    end

    if not session.preview then
        previewChoice(option, choice)
        if not session.preview then
            return
        end
    end

    local props = vehicleService.getProps()
    if not props then
        closeSession('invalidVehicle', true)
        return
    end

    local response = lib.callback.await('qbx_customs:server:checkout', false, {
        zoneIndex = session.zoneIndex,
        zoneId = session.zoneId,
        vehicleNetId = session.vehicleNetId,
        plate = session.plate,
        serviceType = choice.serviceType,
        priceKey = choice.priceKey,
        priceLevel = choice.priceLevel,
        props = props,
        bodyHealth = GetVehicleBodyHealth(vehicleService.get()),
    })

    if not response or response.ok ~= true then
        vehicleService.restoreCommitted()
        session.clearPreview()
        notifyReason(response and response.reason or 'paymentFailed')
        menu.refresh(previewChoice, applyChoice, cancelPreview, 'qbx_customs:choices')
        return
    end

    vehicleService.captureCommitted()
    session.clearPreview()
    session.addToTotal(response.amount or 0)
    feedback.playConfirmSound()
    feedback.notify(locale('notifications.success.installed'), 'success')
    menu.refresh(previewChoice, applyChoice, cancelPreview, 'qbx_customs:choices')
end

local function disableControlsLoop()
    if guardRunning then
        return
    end

    guardRunning = true
    CreateThread(function()
        while session.isOpen do
            for i = 1, #DISABLED_CONTROLS do
                DisableControlAction(0, DISABLED_CONTROLS[i], true)
            end

            if IsPauseMenuActive() then
                closeSession('pauseMenu', true)
                break
            end

            local ok, reason = isSessionVehicleValid()
            if not ok then
                closeSession(reason, true)
                break
            end

            Wait(0)
        end

        guardRunning = false
    end)
end

menu.setCloseHandler(function(reason)
    closeSession(reason, true)
end)

lib.callback.register('qbx_customs:client:getZoneIndex', function()
    return session.zoneIndex
end)

lib.callback.register('qbx_customs:client:getVehicleProps', function()
    return vehicleService.getProps()
end)

local function openCustoms(zoneIndex)
    if session.isOpen or session.isClosing then
        notifyReason('busy')
        return false
    end

    local vehicle = cache.vehicle
    if not vehicleService.isValid(vehicle) then
        notifyReason('invalidVehicle')
        return false
    end

    if vehicleService.isDestroyed(vehicle) then
        notifyReason('destroyedVehicle')
        return false
    end

    if not vehicleService.isDriver(vehicle) then
        notifyReason('notDriver')
        return false
    end

    if not access.isVehicleAllowed(zoneIndex, vehicle) then
        notifyReason('accessDenied')
        return false
    end

    local plate = vehicleService.getPlate(vehicle)
    if not plate or plate == '' then
        notifyReason('notPersisted')
        return false
    end

    local response = lib.callback.await('qbx_customs:server:openSession', false, {
        zoneIndex = zoneIndex,
        zoneId = access.getZoneByIndex(zoneIndex) and access.getZoneByIndex(zoneIndex).id or nil,
        plate = plate,
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
    })

    if not response or response.ok ~= true then
        notifyReason(response and response.reason or 'noSession')
        return false
    end

    session.start({
        zoneId = response.zoneId,
        zoneIndex = zoneIndex,
        vehicle = vehicle,
        vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = plate,
    })

    vehicleService.set(vehicle)
    vehicleService.captureCommitted()
    camera.start(vehicle)
    disableControlsLoop()
    menu.open(previewChoice, applyChoice, cancelPreview)
    return true
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if session.isOpen then
        vehicleService.restoreCommitted()
        camera.stop()
        menu.close()
        TriggerServerEvent('qbx_customs:server:closeSession')
        session.reset()
    end
end)

return openCustoms
