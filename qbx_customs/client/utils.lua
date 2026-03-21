local config = require 'config.client'
local feedback = require 'client.services.feedback'

---@param vehicle number
---@param modType number
---@param modValue number
---@return string
function GetModLabel(vehicle, modType, modValue)
    local customLabels = config.modLabels[modType]
    if customLabels then
        for _, mod in ipairs(customLabels) do
            if mod.id == modValue then
                return mod.label
            end
        end
    end

    if modValue == -1 then return locale('menus.general.stock') end

    local label = GetModTextLabel(vehicle, modType, modValue)
    if not label or label == '' then
        return tostring(modValue)
    end

    local translated = GetLabelText(label)
    return translated == 'NULL' and tostring(modValue) or translated
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
    if not success then
        feedback.notify(locale('notifications.error.money'), 'error')
        return false
    end

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
    feedback.playConfirmSound()
    return true
end
