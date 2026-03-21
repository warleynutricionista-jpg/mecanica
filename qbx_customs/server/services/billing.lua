local sharedConfig = require 'config.shared'

local billing = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

function billing.charge(source, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        return true, nil
    end

    local player = getPlayer(source)
    if not player or not player.Functions then
        return false, 'playerMissing'
    end

    for i = 1, #sharedConfig.billing.accountOrder do
        local account = sharedConfig.billing.accountOrder[i]
        local balance = player.Functions.GetMoney(account)
        if balance and balance >= amount then
            player.Functions.RemoveMoney(account, amount, locale('general.payReason'))
            return true, account
        end
    end

    return false, 'money'
end

function billing.refund(source, amount, account)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        return true
    end

    local player = getPlayer(source)
    if not player or not player.Functions then
        return false
    end

    player.Functions.AddMoney(account or sharedConfig.billing.refundAccountFallback or 'bank', amount, locale('general.refundReason'))
    return true
end

function billing.notifySuccess(source, amount, account)
    if amount <= 0 then
        return
    end

    local accountLabel = account == 'cash' and locale('notifications.success.cashAccount') or locale('notifications.success.bankAccount')
    exports.qbx_core:Notify(source, locale('notifications.success.paid', amount, accountLabel), 'success')
end

return billing
