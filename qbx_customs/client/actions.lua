local session = require 'client.session'
local sharedConfig = require 'config.shared'

local actions = {}

local function getVehicle()
    return session.vehicle
end

local function getPrice(mod, level)
    if mod == 'cosmetic' or mod == 18 then
        return sharedConfig.prices[mod]
    end

    local price = sharedConfig.prices[mod]
    if type(price) == 'table' then
        return price[level] or price[#price] or 0
    end

    return price or 0
end

actions.getPrice = getPrice

function actions.captureCommittedProps()
    session.committedProps = lib.getVehicleProperties(getVehicle())
    if not session.originalProps then
        session.originalProps = table.clone(session.committedProps)
    end
end

function actions.restoreCommitted()
    if not session.committedProps then return end
    lib.setVehicleProperties(getVehicle(), session.committedProps)
    SetVehicleModKit(getVehicle(), 0)
    session.previewOption = nil
    session.previewChoice = nil
end

function actions.restoreOriginal()
    if not session.originalProps then return end
    lib.setVehicleProperties(getVehicle(), session.originalProps)
    SetVehicleModKit(getVehicle(), 0)
    session.committedProps = table.clone(session.originalProps)
    session.previewOption = nil
    session.previewChoice = nil
end

function actions.applyPreview(option, choice)
    actions.restoreCommitted()
    choice.apply(getVehicle())
    session.previewOption = option.id
    session.previewChoice = choice.id
end

function actions.commitChoice(option, choice)
    local success = InstallMod(choice.duplicate, option.priceMod, {
        description = choice.successLabel or locale('menus.general.installed', choice.label),
    }, choice.level)

    if success then
        actions.captureCommittedProps()
        session.sessionTotal += choice.price or 0
    else
        actions.restoreCommitted()
    end

    return success
end

function actions.repairVehicle(price)
    local success = lib.callback.await('qbx_customs:server:repair', false, GetVehicleBodyHealth(getVehicle()))
    if success then
        exports.qbx_core:Notify(locale('notifications.success.repaired'), 'success')
        qbx.playAudio({
            audioName = 'PICK_UP',
            audioRef = 'HUD_FRONTEND_DEFAULT_SOUNDSET'
        })
        local fuelLevel = GetVehicleFuelLevel(getVehicle())
        SetVehicleBodyHealth(getVehicle(), 1000.0)
        SetVehicleEngineHealth(getVehicle(), 1000.0)
        SetVehicleFixed(getVehicle())
        SetVehicleFuelLevel(getVehicle(), fuelLevel)
        actions.captureCommittedProps()
        session.sessionTotal += price
        return true
    end

    exports.qbx_core:Notify(locale('notifications.error.money'), 'error')
    return false
end

return actions
