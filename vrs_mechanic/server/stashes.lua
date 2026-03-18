-- ============================================================
-- VRS_MECHANIC - STASHES SERVER
-- ============================================================

-- Callback: obter conteúdo do stash (inventário)
lib.callback.register('vrs_mechanic:server:getStashContent', function(source, shopId)
    local src = source
    if not shopId then return nil end

    local shop = Config.Shops[shopId]
    if not shop or not shop.stash then return nil end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(src, shopId) then return nil end
    end

    local stashId = ('vrs_mechanic_%s'):format(shopId)
    -- O ox_inventory gerencia o conteúdo do stash automaticamente
    -- Apenas retornamos o ID para o client abrir
    return stashId
end)
