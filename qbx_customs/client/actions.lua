local session = require 'client.session'
local pricing = require 'shared.pricing'
local vehicle = require 'client.services.vehicle'
local feedback = require 'client.services.feedback'
local validator = require 'client.services.validator'

local actions = {}

actions.getPrice = pricing.get
actions.captureCommittedProps = vehicle.captureCommittedProps
actions.restoreCommitted = vehicle.restoreCommitted
actions.restoreOriginal = vehicle.restoreOriginal

local function safelyApply(choice)
    local ok, err = pcall(choice.apply, vehicle.get())
    if ok then
        return true
    end

    lib.print.error(('[qbx_customs] Failed to apply choice %s: %s'):format(choice.id or 'unknown', err))
    feedback.notify(locale('notifications.error.applyFailed'), 'error')
    return false
end

function actions.applyPreview(option, choice)
    if not validator.isRenderableChoice(option, choice) then
        return false
    end

    vehicle.restoreCommitted()
    if not safelyApply(choice) then
        vehicle.restoreCommitted()
        return false
    end

    session.setPreview(option.id, choice.id)
    return true
end

function actions.commitChoice(option, choice)
    if not option or not choice then
        return false
    end

    local success = InstallMod(choice.duplicate, option.priceMod, {
        description = choice.successLabel or locale('menus.general.installed', choice.label),
    }, choice.level)

    if not success then
        vehicle.restoreCommitted()
        return false
    end

    vehicle.captureCommittedProps()
    session.addToTotal(choice.price)
    return true
end

function actions.repairVehicle(price)
    if not vehicle.isDriveable() then
        feedback.notify(locale('notifications.error.invalidVehicle'), 'error')
        return false
    end

    local success = lib.callback.await('qbx_customs:server:repair', false, GetVehicleBodyHealth(vehicle.get()))
    if success ~= true then
        feedback.notify(locale('notifications.error.money'), 'error')
        return false
    end

    vehicle.applyRepairState()
    vehicle.captureCommittedProps()
    session.addToTotal(price)
    feedback.notify(locale('notifications.success.repaired'), 'success')
    feedback.playConfirmSound()
    return true
end

return actions
