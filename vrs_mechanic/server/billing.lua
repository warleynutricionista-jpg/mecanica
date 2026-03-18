-- ============================================================
-- VRS_MECHANIC - BILLING / COBRANÇA SERVER
-- ============================================================

-- Callback: enviar cobrança para jogador
lib.callback.register('vrs_mechanic:server:sendBill', function(source, data)
    local src = source

    if not Config.Billing.enabled then
        return { success = false, reason = 'disabled' }
    end

    local amount = tonumber(data.amount)
    local targetId = tonumber(data.targetId)
    local shopId = data.shopId
    local description = data.description or 'Serviço mecânico'
    local orderId = data.orderId

    if not amount or not targetId then
        return { success = false, reason = 'invalid_data' }
    end

    if amount < Config.Billing.minAmount or amount > Config.Billing.maxAmount then
        return { success = false, reason = 'invalid_amount' }
    end

    if not VRS.CheckCooldown(src, 'billing') then
        return { success = false, reason = 'cooldown' }
    end

    -- Validar acesso
    if shopId and Config.Shops[shopId] then
        local shop = Config.Shops[shopId]
        if shop.type == 'owned' then
            if not VRS.HasShopAccess(src, shopId) then
                return { success = false, reason = 'no_access' }
            end
            if not VRS.IsOnDuty(src) then
                return { success = false, reason = 'not_on_duty' }
            end
        end
    end

    -- Validar distância
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not srcPed or not targetPed or srcPed == 0 or targetPed == 0 then
        return { success = false, reason = 'no_player' }
    end

    local dist = #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed))
    if dist > Config.Billing.maxDistance then
        return { success = false, reason = 'too_far' }
    end

    -- Verificar se target pode pagar
    local targetPlayer = exports.qbx_core:GetPlayer(targetId)
    if not targetPlayer then
        return { success = false, reason = 'target_offline' }
    end

    local targetMoney = targetPlayer.PlayerData.money.bank
    if targetMoney < amount then
        return { success = false, reason = 'target_insufficient' }
    end

    -- Processar pagamento
    targetPlayer.Functions.RemoveMoney('bank', amount, 'vrs_mechanic_bill')

    -- Distribuir pagamento
    local mechanicPlayer = exports.qbx_core:GetPlayer(src)
    if not mechanicPlayer then
        return { success = false, reason = 'error' }
    end

    if Config.Billing.useSociety and shopId then
        -- Tentar usar society fund
        local commission = math.floor(amount * Config.Billing.employeeCommission)
        local societyAmount = amount - commission

        -- Comissão para o mecânico
        if commission > 0 then
            mechanicPlayer.Functions.AddMoney('bank', commission, 'vrs_mechanic_commission')
        end

        -- Resto para society (se disponível via export)
        local success = pcall(function()
            exports['qb-management']:AddMoney(Config.Shops[shopId].job, societyAmount)
        end)

        if not success then
            -- Se society não disponível, tudo para o mecânico
            mechanicPlayer.Functions.AddMoney('bank', societyAmount, 'vrs_mechanic_bill')
        end
    else
        -- Tudo para o mecânico
        mechanicPlayer.Functions.AddMoney('bank', amount, 'vrs_mechanic_bill')
    end

    -- Registrar no banco
    MySQL.insert.await(
        [[INSERT INTO vrs_mechanic_service_logs
          (shop_id, mechanic_citizenid, mechanic_name, customer_citizenid, customer_name,
           service_type, amount, description, work_order_id, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())]],
        {
            shopId or 'unknown',
            mechanicPlayer.PlayerData.citizenid,
            mechanicPlayer.PlayerData.charinfo.firstname .. ' ' .. mechanicPlayer.PlayerData.charinfo.lastname,
            targetPlayer.PlayerData.citizenid,
            targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
            'billing',
            amount,
            description,
            orderId,
        }
    )

    -- Notificar target
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Cobrança Mecânica',
        description = ('Cobrança de R$ %s paga automaticamente.'):format(VRS.FormatMoney(amount)),
        type = 'inform',
    })

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'billing',
        source = src,
        target = targetId,
        amount = amount,
        shopId = shopId,
    })

    return { success = true, amount = amount }
end)

-- Callback: obter jogadores próximos para cobrança
lib.callback.register('vrs_mechanic:server:getNearbyPlayers', function(source)
    local src = source
    local srcPed = GetPlayerPed(src)
    if not srcPed or srcPed == 0 then return {} end

    local srcCoords = GetEntityCoords(srcPed)
    local nearby = {}

    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        if playerId ~= src then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                if #(srcCoords - targetCoords) <= Config.Billing.maxDistance then
                    local player = exports.qbx_core:GetPlayer(playerId)
                    if player then
                        nearby[#nearby + 1] = {
                            id = playerId,
                            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                        }
                    end
                end
            end
        end
    end

    return nearby
end)

-- Callback: obter histórico de faturamento
lib.callback.register('vrs_mechanic:server:getBillingHistory', function(source, shopId)
    local src = source
    if not shopId then return {} end
    if not VRS.HasShopAccess(src, shopId) then return {} end

    local results = MySQL.query.await(
        [[SELECT * FROM vrs_mechanic_service_logs
          WHERE shop_id = ?
          ORDER BY created_at DESC LIMIT 50]],
        { shopId }
    )

    return results or {}
end)

-- Callback: obter faturamento total
lib.callback.register('vrs_mechanic:server:getRevenue', function(source, shopId)
    local src = source
    if not shopId then return 0 end
    if not VRS.HasShopAccess(src, shopId) then return 0 end

    local result = MySQL.query.await(
        'SELECT COALESCE(SUM(amount), 0) as total FROM vrs_mechanic_service_logs WHERE shop_id = ?',
        { shopId }
    )

    return result and result[1] and result[1].total or 0
end)
