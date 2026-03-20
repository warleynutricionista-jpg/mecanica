local Bridge = {}

if Shared.Framework == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Shared.Framework == 'qbx' then
    QBCore = exports['qbx_core']:GetCoreObject()
elseif Shared.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

function Bridge:GetPlayerCitizenId(id)
    if Shared.Framework == 'qb' or Shared.Framework == 'qbx' then
        local player = QBCore.Functions.GetPlayer(id)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    elseif Shared.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(id)
        return xPlayer and xPlayer.getIdentifier() or nil
    elseif Shared.Framework == 'ox' then
        local player = Ox.GetPlayer(id)
        return player and player.charId or nil
    end
end

function Bridge:GetPlayer(id)
    if Shared.Framework == 'qb' or Shared.Framework == 'qbx' then
        return QBCore.Functions.GetPlayer(id)
    elseif Shared.Framework == 'esx' then
        return ESX.GetPlayerFromId(id)
    elseif Shared.Framework == 'ox' then
        return Ox.GetPlayer(id)
    end
end

function Bridge:GetPlayerJob(id)
    if Shared.Framework == 'qb' or Shared.Framework == 'qbx' then
        local player = QBCore.Functions.GetPlayer(id)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or nil
    elseif Shared.Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(id)
        return xPlayer and xPlayer.getJob().name or nil
    elseif Shared.Framework == 'ox' then
        local player = Ox.GetPlayer(id)
        return player and player.getGroups() or nil
    end
end

function Bridge:AddItem(src, item, info)
    if Shared.Inventory == 'ox' then
        exports.ox_inventory:AddItem(src, item, 1, info)
    elseif Shared.Inventory == 'qb' then
        local Player = self:GetPlayer(src)
        if not Player then return false end
        Player.Functions.AddItem(item, 1, false, info)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
    end
    return true
end

function Bridge:RemoveItem(src, item, slot)
    if Shared.Inventory == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, 1, false, slot)
    elseif Shared.Inventory == 'qb' then
        local Player = self:GetPlayer(src)
        if not Player then return false end
        Player.Functions.RemoveItem(item, 1, slot)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove')
        return true
    end
    return false
end

function Bridge:GetPlayerItemsByName(src, item)
    if Shared.Inventory == 'ox' then
        return exports.ox_inventory:GetSlotsWithItem(src, item)
    elseif Shared.Inventory == 'qb' then
        local Player = self:GetPlayer(src)
        return Player and Player.Functions.GetItemsByName(item) or {}
    end
    return {}
end

function Bridge:GetPlayerItemByName(src, item)
    if Shared.Inventory == 'ox' then
        return exports.ox_inventory:GetSlotWithItem(src, item)
    elseif Shared.Inventory == 'qb' then
        local Player = self:GetPlayer(src)
        return Player and Player.Functions.GetItemByName(item) or nil
    end
end

function Bridge:HasItem(src, item, amount)
    amount = amount or 1
    local found = self:GetPlayerItemByName(src, item)
    if not found then return false end
    if Shared.Inventory == 'ox' then
        return (found.count or 0) >= amount
    end
    return (found.amount or 0) >= amount
end

function Bridge:TryRemoveItem(src, item, amount)
    amount = amount or 1
    if Shared.Inventory == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end

    local Player = self:GetPlayer(src)
    if not Player then return false end
    local itemData = Player.Functions.GetItemByName(item)
    if not itemData or (itemData.amount or 0) < amount then return false end
    return Player.Functions.RemoveItem(item, amount, itemData.slot)
end

function Bridge:RemovePlayerKeyItem(src, info)
    local items = self:GetPlayerItemsByName(src, 'vehiclekey')
    for _, v in pairs(items) do
        if Shared.Inventory == 'ox' then
            if lib.table.matches(v.metadata, info) then
                exports.ox_inventory:RemoveItem(src, 'vehiclekey', 1, false, v.slot)
                return true
            end
        elseif Shared.Inventory == 'qb' then
            if lib.table.matches(v.info, info) then
                local Player = self:GetPlayer(src)
                if not Player then return false end
                Player.Functions.RemoveItem(src, 'vehiclekey', 1, v.slot)
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['vehiclekey'], 'remove')
                return true
            end
        end
    end
    return false
end

return Bridge
