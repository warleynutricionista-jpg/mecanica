-- ============================================================
-- VRS_MECHANIC - MANAGEMENT SERVER
-- ============================================================

-- ============================================================
-- FUNCIONÁRIOS
-- ============================================================

-- Callback: listar funcionários da oficina
lib.callback.register('vrs_mechanic:server:getEmployees', function(source, shopId)
    local src = source
    if not shopId then return {} end
    if not VRS.HasShopAccess(src, shopId) then return {} end

    local shop = Config.Shops[shopId]
    if not shop or not shop.job then return {} end

    local results = MySQL.query.await(
        [[SELECT e.citizenid, e.grade, e.hired_at,
                 p.charinfo
          FROM vrs_mechanic_employees e
          LEFT JOIN players p ON p.citizenid = e.citizenid
          WHERE e.shop_id = ?
          ORDER BY e.grade DESC]],
        { shopId }
    )

    if not results then return {} end

    local employees = {}
    for _, row in ipairs(results) do
        local charinfo = row.charinfo and json.decode(row.charinfo) or {}
        local name = 'Desconhecido'
        if charinfo.firstname then
            name = charinfo.firstname .. ' ' .. (charinfo.lastname or '')
        end

        -- Verificar se está online
        local isOnline = false
        for _, playerId in ipairs(GetPlayers()) do
            local player = exports.qbx_core:GetPlayer(tonumber(playerId))
            if player and player.PlayerData.citizenid == row.citizenid then
                isOnline = true
                break
            end
        end

        employees[#employees + 1] = {
            citizenid = row.citizenid,
            name = name,
            grade = row.grade,
            hiredAt = row.hired_at,
            online = isOnline,
        }
    end

    return employees
end)

-- Callback: contratar funcionário (por cidadão ID ou jogador próximo)
lib.callback.register('vrs_mechanic:server:hireEmployee', function(source, shopId, targetId)
    local src = source

    if not VRS.IsManager(src, shopId) then
        return { success = false, reason = 'no_permission' }
    end

    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        return { success = false, reason = 'player_not_found' }
    end

    local citizenid = targetPlayer.PlayerData.citizenid

    -- Verificar se já é funcionário
    local existing = MySQL.query.await(
        'SELECT id FROM vrs_mechanic_employees WHERE citizenid = ? AND shop_id = ?',
        { citizenid, shopId }
    )
    if existing and #existing > 0 then
        return { success = false, reason = 'already_hired' }
    end

    -- Inserir no banco
    MySQL.insert.await(
        'INSERT INTO vrs_mechanic_employees (shop_id, citizenid, grade, hired_at) VALUES (?, ?, ?, NOW())',
        { shopId, citizenid, 0 }
    )

    -- Atribuir job via framework
    local shop = Config.Shops[shopId]
    if shop and shop.job then
        targetPlayer.Functions.SetJob(shop.job, 0)
    end

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'hire',
        source = src,
        target = targetId,
        shopId = shopId,
    })

    return { success = true }
end)

-- Callback: demitir funcionário
lib.callback.register('vrs_mechanic:server:fireEmployee', function(source, shopId, citizenid)
    local src = source

    if not VRS.IsManager(src, shopId) then
        return { success = false, reason = 'no_permission' }
    end

    MySQL.update.await(
        'DELETE FROM vrs_mechanic_employees WHERE citizenid = ? AND shop_id = ?',
        { citizenid, shopId }
    )

    -- Remover job do jogador se estiver online
    for _, playerId in ipairs(GetPlayers()) do
        local player = exports.qbx_core:GetPlayer(tonumber(playerId))
        if player and player.PlayerData.citizenid == citizenid then
            player.Functions.SetJob('unemployed', 0)
            TriggerClientEvent('ox_lib:notify', tonumber(playerId), {
                title = 'Emprego',
                description = 'Você foi demitido da oficina.',
                type = 'error',
            })
            break
        end
    end

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'fire',
        source = src,
        citizenid = citizenid,
        shopId = shopId,
    })

    return { success = true }
end)

-- ============================================================
-- PREÇOS
-- ============================================================

-- Callback: obter preços customizados
lib.callback.register('vrs_mechanic:server:getShopPrices', function(source, shopId)
    local src = source
    if not shopId then return {} end

    local shop = Config.Shops[shopId]
    if not shop then return {} end
    if shop.type == 'owned' and not VRS.HasShopAccess(src, shopId) then return {} end

    -- Carregar overrides do banco
    local overrides = MySQL.query.await(
        'SELECT service, price FROM vrs_mechanic_price_overrides WHERE shop_id = ?',
        { shopId }
    )

    -- Mesclar base + overrides
    local prices = {}
    for service, basePrice in pairs(shop.basePrices) do
        prices[service] = basePrice
    end

    if overrides then
        for _, row in ipairs(overrides) do
            prices[row.service] = row.price
        end
    end

    return prices
end)

-- Callback: atualizar preço
lib.callback.register('vrs_mechanic:server:updatePrice', function(source, shopId, service, price)
    local src = source

    if not VRS.IsManager(src, shopId) then
        return { success = false, reason = 'no_permission' }
    end

    price = tonumber(price)
    if not price or price < 0 then
        return { success = false, reason = 'invalid_price' }
    end

    MySQL.insert.await(
        [[INSERT INTO vrs_mechanic_price_overrides (shop_id, service, price)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE price = VALUES(price)]],
        { shopId, service, price }
    )

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'price_update',
        source = src,
        shopId = shopId,
        service = service,
        price = price,
    })

    return { success = true }
end)

-- ============================================================
-- ESTATÍSTICAS
-- ============================================================

-- Callback: obter estatísticas da oficina
lib.callback.register('vrs_mechanic:server:getShopStats', function(source, shopId)
    local src = source
    if not shopId then return nil end
    if not VRS.HasShopAccess(src, shopId) then return nil end

    local totalOrders = MySQL.query.await(
        'SELECT COUNT(*) as total FROM vrs_mechanic_work_orders WHERE shop_id = ?',
        { shopId }
    )

    local completedOrders = MySQL.query.await(
        'SELECT COUNT(*) as total FROM vrs_mechanic_work_orders WHERE shop_id = ? AND status IN (?, ?)',
        { shopId, VRS.OrderStatus.DONE, VRS.OrderStatus.DELIVERED }
    )

    local revenue = MySQL.query.await(
        'SELECT COALESCE(SUM(amount), 0) as total FROM vrs_mechanic_service_logs WHERE shop_id = ?',
        { shopId }
    )

    local employeeCount = MySQL.query.await(
        'SELECT COUNT(*) as total FROM vrs_mechanic_employees WHERE shop_id = ?',
        { shopId }
    )

    return {
        totalOrders = totalOrders and totalOrders[1] and totalOrders[1].total or 0,
        completedOrders = completedOrders and completedOrders[1] and completedOrders[1].total or 0,
        revenue = revenue and revenue[1] and revenue[1].total or 0,
        employeeCount = employeeCount and employeeCount[1] and employeeCount[1].total or 0,
    }
end)
