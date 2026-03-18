-- ============================================================
-- VRS_MECHANIC - WORK ORDERS (ORDENS DE SERVIÇO) SERVER
-- ============================================================

-- ============================================================
-- CALLBACKS
-- ============================================================

-- Criar nova OS
lib.callback.register('vrs_mechanic:server:createWorkOrder', function(source, data)
    local src = source

    if not data.shopId or not data.plate then
        return { success = false, reason = 'invalid_data' }
    end

    if not VRS.HasShopAccess(src, data.shopId) then
        return { success = false, reason = 'no_access' }
    end

    local shop = Config.Shops[data.shopId]
    if shop and shop.type == 'owned' and not VRS.IsOnDuty(src) then
        return { success = false, reason = 'not_on_duty' }
    end

    local player = VRS.GetPlayerData(src)
    if not player then return { success = false, reason = 'no_player' } end

    local mechanicName = player.charinfo.firstname .. ' ' .. player.charinfo.lastname

    local id = MySQL.insert.await(
        [[INSERT INTO vrs_mechanic_work_orders
          (shop_id, plate, model, owner_name, mechanic_name, mechanic_citizenid,
           problems, materials, budget, notes, status, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())]],
        {
            data.shopId,
            data.plate,
            data.model or '',
            data.ownerName or 'Desconhecido',
            mechanicName,
            player.citizenid,
            json.encode(data.problems or {}),
            json.encode(data.materials or {}),
            data.budget or 0,
            data.notes or '',
            VRS.OrderStatus.OPEN,
        }
    )

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'work_order_create',
        source = src,
        orderId = id,
        shopId = data.shopId,
        plate = data.plate,
    })

    return { success = true, orderId = id }
end)

-- Listar OS de uma oficina
lib.callback.register('vrs_mechanic:server:getWorkOrders', function(source, shopId, statusFilter)
    local src = source

    if not shopId then return {} end
    if not VRS.HasShopAccess(src, shopId) then return {} end

    local query, params

    if statusFilter and statusFilter ~= '' then
        query = [[SELECT * FROM vrs_mechanic_work_orders
                  WHERE shop_id = ? AND status = ?
                  ORDER BY created_at DESC LIMIT 50]]
        params = { shopId, statusFilter }
    else
        query = [[SELECT * FROM vrs_mechanic_work_orders
                  WHERE shop_id = ?
                  ORDER BY created_at DESC LIMIT 50]]
        params = { shopId }
    end

    local results = MySQL.query.await(query, params)

    if not results then return {} end

    -- Decodificar JSON
    for _, order in ipairs(results) do
        order.problems = order.problems and json.decode(order.problems) or {}
        order.materials = order.materials and json.decode(order.materials) or {}
    end

    return results
end)

-- Obter OS específica
lib.callback.register('vrs_mechanic:server:getWorkOrder', function(source, orderId)
    local src = source
    local result = MySQL.query.await(
        'SELECT * FROM vrs_mechanic_work_orders WHERE id = ?',
        { orderId }
    )
    if not result or not result[1] then return nil end

    local order = result[1]
    if not VRS.HasShopAccess(src, order.shop_id) then return nil end
    order.problems = order.problems and json.decode(order.problems) or {}
    order.materials = order.materials and json.decode(order.materials) or {}
    return order
end)

-- Atualizar status da OS
lib.callback.register('vrs_mechanic:server:updateWorkOrderStatus', function(source, orderId, newStatus)
    local src = source

    if not orderId or not newStatus then
        return { success = false, reason = 'invalid_data' }
    end

    -- Validar status
    local validStatuses = {
        [VRS.OrderStatus.OPEN] = true,
        [VRS.OrderStatus.PROGRESS] = true,
        [VRS.OrderStatus.WAITING] = true,
        [VRS.OrderStatus.DONE] = true,
        [VRS.OrderStatus.DELIVERED] = true,
    }
    if not validStatuses[newStatus] then
        return { success = false, reason = 'invalid_status' }
    end

    -- Verificar se a OS existe e o jogador tem acesso
    local order = MySQL.query.await(
        'SELECT shop_id FROM vrs_mechanic_work_orders WHERE id = ?',
        { orderId }
    )
    if not order or not order[1] then
        return { success = false, reason = 'not_found' }
    end

    if not VRS.HasShopAccess(src, order[1].shop_id) then
        return { success = false, reason = 'no_access' }
    end

    MySQL.update.await(
        'UPDATE vrs_mechanic_work_orders SET status = ?, updated_at = NOW() WHERE id = ?',
        { newStatus, orderId }
    )

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'work_order_update',
        source = src,
        orderId = orderId,
        newStatus = newStatus,
    })

    return { success = true }
end)

-- Atualizar OS completa
lib.callback.register('vrs_mechanic:server:updateWorkOrder', function(source, orderId, updates)
    local src = source

    if not orderId or not updates then
        return { success = false, reason = 'invalid_data' }
    end

    local order = MySQL.query.await(
        'SELECT shop_id FROM vrs_mechanic_work_orders WHERE id = ?',
        { orderId }
    )
    if not order or not order[1] then
        return { success = false, reason = 'not_found' }
    end

    if not VRS.HasShopAccess(src, order[1].shop_id) then
        return { success = false, reason = 'no_access' }
    end

    local setClauses = {}
    local params = {}

    if updates.problems then
        setClauses[#setClauses + 1] = 'problems = ?'
        params[#params + 1] = json.encode(updates.problems)
    end
    if updates.materials then
        setClauses[#setClauses + 1] = 'materials = ?'
        params[#params + 1] = json.encode(updates.materials)
    end
    if updates.budget ~= nil then
        setClauses[#setClauses + 1] = 'budget = ?'
        params[#params + 1] = updates.budget
    end
    if updates.notes ~= nil then
        setClauses[#setClauses + 1] = 'notes = ?'
        params[#params + 1] = updates.notes
    end
    if updates.status ~= nil then
        setClauses[#setClauses + 1] = 'status = ?'
        params[#params + 1] = updates.status
    end

    if #setClauses == 0 then
        return { success = false, reason = 'no_changes' }
    end

    setClauses[#setClauses + 1] = 'updated_at = NOW()'
    params[#params + 1] = orderId

    MySQL.update.await(
        ('UPDATE vrs_mechanic_work_orders SET %s WHERE id = ?'):format(table.concat(setClauses, ', ')),
        params
    )

    return { success = true }
end)

-- Deletar OS
lib.callback.register('vrs_mechanic:server:deleteWorkOrder', function(source, orderId)
    local src = source

    local order = MySQL.query.await(
        'SELECT shop_id FROM vrs_mechanic_work_orders WHERE id = ?',
        { orderId }
    )
    if not order or not order[1] then
        return { success = false, reason = 'not_found' }
    end

    if not VRS.IsManager(src, order[1].shop_id) then
        return { success = false, reason = 'no_permission' }
    end

    MySQL.update.await(
        'DELETE FROM vrs_mechanic_work_orders WHERE id = ?',
        { orderId }
    )

    return { success = true }
end)
