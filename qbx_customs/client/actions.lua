local session = require 'client.session'
local pricing = require 'shared.pricing'
local vehicle = require 'client.services.vehicle'
local feedback = require 'client.services.feedback'

local actions = {}

actions.getPrice = pricing.get

actions.captureCommittedProps = vehicle.captureCommittedProps
actions.restoreCommitted = vehicle.restoreCommitted
actions.restoreOriginal = vehicle.restoreOriginal

function actions.applyPreview(option, choice)
    if not option or not choice or not choice.apply then return false end

    vehicle.restoreCommitted()
    choice.apply(vehicle.get())
    session.previewOption = option.id
    session.previewChoice = choice.id
    return true
end

function actions.commitChoice(option, choice)
    if not option or not choice then return false end

    local success = InstallMod(choice.duplicate, option.priceMod, {
        description = choice.successLabel or locale('menus.general.installed', choice.label),
    }, choice.level)

    if not success then
        vehicle.restoreCommitted()
        return false
    end

    vehicle.captureCommittedProps()
    session.sessionTotal += choice.price or 0
    return true
end

function actions.repairVehicle(price)
    if not vehicle.isDriveable() then
        feedback.notify(locale('notifications.error.invalidVehicle'), 'error')
        return false
    end

    local success = lib.callback.await('qbx_customs:server:repair', false, GetVehicleBodyHealth(vehicle.get()))
    if not success then
        feedback.notify(locale('notifications.error.money'), 'error')
        return false
    end

    vehicle.applyRepairState()
    vehicle.captureCommittedProps()
    session.sessionTotal += price or 0
    feedback.notify(locale('notifications.success.repaired'), 'success')
    feedback.playConfirmSound()
    return true
end

return actions
