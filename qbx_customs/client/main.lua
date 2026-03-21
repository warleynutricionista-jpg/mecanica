local dragcam = require 'client.dragcam'
local session = require 'client.session'
local actions = require 'client.actions'
local ui = require 'client.ui'

local startDragCam = dragcam.startDragCam
local stopDragCam = dragcam.stopDragCam

local function setVehicle(vehicle)
    session.vehicle = vehicle
    SetVehicleModKit(vehicle, 0)
end

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
    actions.restoreCommitted()
    session.isOpen = false
    stopDragCam()
    ui.hide()

    if saveVehicle then
        TriggerServerEvent('qbx_customs:server:saveVehicleProps')
    end

    session.selectedCategory = nil
    session.selectedOption = nil
    session.selectedChoice = nil
    session.previewOption = nil
    session.previewChoice = nil
    session.committedProps = nil
    session.originalProps = nil
    session.sessionTotal = 0
    session.vehicle = 0
end

RegisterNUICallback('selectCategory', function(data, cb)
    ui.selectCategory(data.categoryId)
    cb(1)
end)

RegisterNUICallback('selectOption', function(data, cb)
    ui.selectOption(data.optionId)
    cb(1)
end)

RegisterNUICallback('previewChoice', function(data, cb)
    ui.previewChoice(data.optionId, data.choiceId)
    cb(1)
end)

RegisterNUICallback('installChoice', function(data, cb)
    ui.installChoice(data.optionId, data.choiceId)
    cb(1)
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb(1)
end)

RegisterNUICallback('restorePreview', function(_, cb)
    actions.restoreCommitted()
    ui.refresh()
    cb(1)
end)

lib.callback.register('qbx_customs:client:vehicleProps', function()
    return lib.getVehicleProperties(session.vehicle)
end)

lib.onCache('vehicle', function(vehicle)
    if session.isOpen and not vehicle then
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
    if not cache.vehicle or session.isOpen then return end

    session.isOpen = true
    setVehicle(cache.vehicle)
    actions.captureCommittedProps()
    disableControls()
    startDragCam(session.vehicle)
    ui.open()
end
