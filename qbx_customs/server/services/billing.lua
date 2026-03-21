local pricing = require 'shared.pricing'

local billing = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

function billing.removeMoney(source, amount)
    if amount <= 0 then return true end

    local player = getPlayer(source)
    if not player then return false end

    local cashBalance = player.Functions.GetMoney('cash')
    if cashBalance >= amount then
        player.Functions.RemoveMoney('cash', amount, locale('general.payReason'))
        return true
    end

    local bankBalance = player.Functions.GetMoney('bank')
    if bankBalance >= amount then
        player.Functions.RemoveMoney('bank', amount, locale('general.payReason'))
        exports.qbx_core:Notify(source, locale('notifications.success.paid', amount), 'success')
        return true
    end

    return false
end

function billing.chargeForMod(source, mod, level)
    return billing.removeMoney(source, pricing.get(mod, level))
end

function billing.chargeForRepair(source, bodyHealth)
    return billing.removeMoney(source, pricing.getRepairPrice(bodyHealth))
end

return billing
