-- ============================================================
-- VRS_MECHANIC - LOGGING SERVER
-- ============================================================

--- Log de ações
RegisterNetEvent('vrs_mechanic:server:log', function(data)
    if not Config.Logging.enabled then return end

    local src = data.source
    local playerName = 'Sistema'

    if src then
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            playerName = ('%s %s (%s)'):format(
                player.PlayerData.charinfo.firstname,
                player.PlayerData.charinfo.lastname,
                player.PlayerData.citizenid
            )
        end
    end

    -- Registrar no banco
    MySQL.insert(
        [[INSERT INTO vrs_mechanic_service_logs
          (shop_id, mechanic_citizenid, mechanic_name, service_type, description, amount, created_at)
          VALUES (?, ?, ?, ?, ?, ?, NOW())]],
        {
            data.shopId or 'system',
            data.source and tostring(data.source) or 'system',
            playerName,
            data.action or 'unknown',
            json.encode(data),
            data.amount or 0,
        }
    )

    -- Discord webhook (opcional)
    if Config.Logging.discord_webhook and Config.Logging.discord_webhook ~= '' then
        local message = ('[vrs_mechanic] **%s** - Jogador: %s'):format(
            data.action or 'unknown',
            playerName
        )

        if data.plate then
            message = message .. (' | Placa: %s'):format(data.plate)
        end
        if data.part then
            message = message .. (' | Peça: %s'):format(data.part)
        end
        if data.amount then
            message = message .. (' | Valor: R$ %s'):format(VRS.FormatMoney(data.amount))
        end
        if data.shopId then
            message = message .. (' | Oficina: %s'):format(data.shopId)
        end

        PerformHttpRequest(Config.Logging.discord_webhook, function() end, 'POST',
            json.encode({
                content = message,
                username = 'VRS Mechanic',
            }),
            { ['Content-Type'] = 'application/json' }
        )
    end
end)
