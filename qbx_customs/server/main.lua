lib.versionCheck('Qbox-project/qbx_customs')
local sharedConfig = require 'config.shared'

---@return number
local function getModPrice(mod, level)
    local price = sharedConfig.prices[mod]
    if type(price) == 'table' then
        return price[level] or price[#price] or 0
    end

    return price or 0
end

---@param source number
---@param amount number
---@return boolean
local function removeMoney(source, amount)
    if amount <= 0 then return true end

    local player = exports.qbx_core:GetPlayer(source)
    local cashBalance = player.Functions.GetMoney('cash')
    local bankBalance = player.Functions.GetMoney('bank')

    if cashBalance >= amount then
        player.Functions.RemoveMoney('cash', amount, locale('general.payReason'))
        return true
    elseif bankBalance >= amount then
        player.Functions.RemoveMoney('bank', amount, locale('general.payReason'))
        exports.qbx_core:Notify(source, locale('notifications.success.paid', amount), 'success')
        return true
    end

    return false
end

lib.callback.register('qbx_customs:server:pay', function(source, mod, level)
    local zone = lib.callback.await('qbx_customs:client:zone', source)

    for i, v in ipairs(sharedConfig.zones) do
        if i == zone and v.freeMods then
            local playerJob = exports.qbx_core:GetPlayer(source)?.PlayerData?.job?.name
            for _, job in ipairs(v.freeMods) do
                if playerJob == job then
                    return true
                end
            end
        end
    end

    return removeMoney(source, getModPrice(mod, level))
end)

lib.callback.register('qbx_customs:server:repair', function(source, bodyHealth)
    local zone = lib.callback.await('qbx_customs:client:zone', source)

    for i, v in ipairs(sharedConfig.zones) do
        if i == zone and v.freeRepair then
            local playerJob = exports.qbx_core:GetPlayer(source)?.PlayerData?.job?.name
            for _, job in ipairs(v.freeRepair) do
                if playerJob == job then
                    return true
                end
            end
        end
    end

    local price = math.ceil(1000 - bodyHealth)
    return removeMoney(source, price)
end)

local function isVehicleOwned(plate)
    return MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {plate}) and true or false
end

RegisterNetEvent('qbx_customs:server:saveVehicleProps', function()
    local src = source --[[@as number]]
    local vehicleProps = lib.callback.await('qbx_customs:client:vehicleProps', src)
    if vehicleProps and isVehicleOwned(vehicleProps.plate) then
        MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
    end
end)
