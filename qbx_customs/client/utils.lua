local config = require 'config.client'
local feedback = require 'client.services.feedback'

local modLabelIndex = {}
for modType, labels in pairs(config.modLabels) do
    modLabelIndex[modType] = {}

    for i = 1, #labels do
        local entry = labels[i]
        modLabelIndex[modType][entry.id] = entry.label
    end
end

local function resolveTranslatedLabel(label)
    if not label or label == '' then
        return nil
    end

    local translated = GetLabelText(label)
    if translated == 'NULL' then
        return nil
    end

    return translated
end

---@param vehicle number
---@param modType number
---@param modValue number
---@return string
function GetModLabel(vehicle, modType, modValue)
    local customLabel = modLabelIndex[modType] and modLabelIndex[modType][modValue]
    if customLabel then
        return customLabel
    end

    if modValue == -1 then
        return locale('menus.general.stock')
    end

    local label = resolveTranslatedLabel(GetModTextLabel(vehicle, modType, modValue))
    if label then
        return label
    end

    return tostring(modValue)
end

local function notifyInstalled(props)
    exports.qbx_core:Notify(
        props?.title or locale('notifications.props.installTitle'),
        props?.position or 'top',
        props?.duration,
        props?.description,
        props?.position or 'top',
        props?.style,
        props?.icon or 'fa-solid fa-wrench',
        props?.iconColor
    )
end

---@param duplicate boolean
---@param mod 'repair' | 'cosmetic' | 11 | 12 | 13 | 15 | 16 | 18
---@param props NotifyProps?
---@param level number?
function InstallMod(duplicate, mod, props, level)
    if duplicate then
        feedback.notify(locale('notifications.error.alreadyInstalled'), 'error')
        return false
    end

    local success = lib.callback.await('qbx_customs:server:pay', false, mod, level)
    if success ~= true then
        feedback.notify(locale('notifications.error.money'), 'error')
        return false
    end

    notifyInstalled(props)
    feedback.playConfirmSound()
    return true
end
