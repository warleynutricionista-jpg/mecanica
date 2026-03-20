-- ============================================================
-- VRS_MECHANIC - INVENTORY SERVER (ox_inventory integration)
-- ============================================================

-- Registrar stashes para cada oficina
CreateThread(function()
    Wait(1000) -- Aguardar ox_inventory inicializar

    for shopId, shop in pairs(Config.Shops) do
        if shop.stash and shop.type == 'owned' then
            local stashId = ('vrs_mechanic_%s'):format(shopId)
            local groups = shop.job and { [shop.job] = 0 } or nil
            local slots = tonumber(shop.stash.slots) or 50
            local weight = tonumber(shop.stash.weight) or 50000

            exports.ox_inventory:RegisterStash(
                stashId,
                ('Estoque - %s'):format(shop.label),
                slots,
                weight,
                nil, -- owner (nil = compartilhado pelo job)
                groups
            )
        end
    end

    print('[vrs_mechanic] ^2Stashes registrados^0')
end)

-- Callback: abrir stash da oficina
lib.callback.register('vrs_mechanic:server:openStash', function(source, shopId)
    local src = source
    local shop = Config.Shops[shopId]
    if not shop or not shop.stash then return false end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(src, shopId) then return false end
        if not VRS.IsOnDuty(src) then return false end
    end

    local stashId = ('vrs_mechanic_%s'):format(shopId)
    exports.ox_inventory:forceOpenInventory(src, 'stash', stashId)
    return true
end)

-- Callback: verificar se jogador tem item
lib.callback.register('vrs_mechanic:server:hasItem', function(source, item, amount)
    amount = amount or 1
    local count = exports.ox_inventory:Search(source, 'count', item)
    return count >= amount
end)

-- Callback: remover item
lib.callback.register('vrs_mechanic:server:removeItem', function(source, item, amount)
    amount = amount or 1
    local count = exports.ox_inventory:Search(source, 'count', item)
    if count < amount then return false end
    return exports.ox_inventory:RemoveItem(source, item, amount)
end)
