-- ============================================================
-- VRS_MECHANIC - UPGRADES SERVER CALLBACK
-- ============================================================

-- Callback: instalar upgrade
lib.callback.register('vrs_mechanic:server:installUpgrade', function(source, data)
    local src = source

    if not Config.Upgrades.enabled then
        return { success = false, reason = 'disabled' }
    end

    local plate = data.plate
    local upgradeType = data.upgradeType
    local shopId = data.shopId
    local netId = data.netId

    if not plate or not upgradeType then
        return { success = false, reason = 'invalid_data' }
    end

    if not VRS.CheckCooldown(src, 'upgrade') then
        return { success = false, reason = 'cooldown' }
    end

    -- Validar acesso
    if Config.Upgrades.requireJob and shopId then
        if not VRS.HasShopAccess(src, shopId) then
            return { success = false, reason = 'no_access' }
        end
    end

    if Config.Upgrades.requireDuty and not VRS.IsOnDuty(src) then
        return { success = false, reason = 'not_on_duty' }
    end

    local serviceValid, serviceReason = VRS.ValidateServiceContext(src, 'upgrade', upgradeType, {
        plate = plate,
        netId = netId,
        shopId = shopId,
    })
    if not serviceValid then
        return { success = false, reason = serviceReason or 'invalid_vehicle' }
    end

    -- Verificar e consumir materiais
    local materials = Config.UpgradeMaterials[upgradeType]
    if not materials then
        return { success = false, reason = 'unknown_upgrade' }
    end

    -- Verificar todos os itens
    for _, req in ipairs(materials) do
        if req.amount > 0 then
            local count = exports.ox_inventory:Search(src, 'count', req.item)
            if count < req.amount then
                return { success = false, reason = 'no_materials' }
            end
        end
    end

    -- Remover itens
    for _, req in ipairs(materials) do
        if req.amount > 0 then
            exports.ox_inventory:RemoveItem(src, req.item, req.amount)
        end
    end

    -- Log
    TriggerEvent('vrs_mechanic:server:log', {
        action = 'upgrade_install',
        source = src,
        plate = plate,
        upgradeType = upgradeType,
        shopId = shopId,
    })

    return { success = true }
end)
