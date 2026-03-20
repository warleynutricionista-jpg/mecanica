-- ============================================================
-- VRS_MECHANIC - SERVER MAIN
-- ============================================================

VRS = VRS or {}
VRS.LoadLocale()

-- Cache de cooldowns por jogador
local playerCooldowns = {}

--- Verifica se o jogador tem o job correto para uma oficina
---@param source number
---@param shopId string
---@return boolean
function VRS.HasShopAccess(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop then return false end

    -- Self-service: qualquer um pode acessar
    if shop.type == 'self-service' then return true end

    -- Owned: precisa ter o job correto
    if not shop.job then return true end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    return player.PlayerData.job.name == shop.job
end

--- Verifica se o jogador está em duty
---@param source number
---@return boolean
function VRS.IsOnDuty(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    return player.PlayerData.job.onduty == true
end

--- Verifica se o jogador é gerente da oficina
---@param source number
---@param shopId string
---@return boolean
function VRS.IsManager(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop then return false end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    if shop.job and player.PlayerData.job.name ~= shop.job then return false end

    local grade = player.PlayerData.job.grade.level or 0
    local minManagementGrade = 999

    for _, g in ipairs(shop.managementGrades or Config.PanelAccess.managementGrades or {}) do
        if g < minManagementGrade then
            minManagementGrade = g
        end
    end

    if minManagementGrade == 999 then
        minManagementGrade = 0
    end

    if VRS.IsBoss and VRS.IsBoss(source, shopId) then
        return true
    end

    return grade >= minManagementGrade
end

--- Retorna dados do jogador
---@param source number
---@return table|nil
function VRS.GetPlayerData(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    return player.PlayerData
end

--- Verifica cooldown de ação
---@param source number
---@param action string
---@return boolean -- true se pode executar
function VRS.CheckCooldown(source, action)
    local key = ('%d_%s'):format(source, action)
    local cooldown = Config.Cooldowns[action] or 3000
    local now = GetGameTimer()

    if playerCooldowns[key] and (now - playerCooldowns[key]) < cooldown then
        return false
    end

    playerCooldowns[key] = now
    return true
end

--- Valida distância entre jogador e entidade
---@param source number
---@param entity number netId
---@param maxDistance number
---@return boolean
function VRS.ValidateDistance(source, entity, maxDistance)
    local playerPed = GetPlayerPed(source)
    if not playerPed or playerPed == 0 then return false end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    local playerCoords = GetEntityCoords(playerPed)
    local entityCoords = GetEntityCoords(entity)

    return #(playerCoords - entityCoords) <= maxDistance
end


--- Valida se o veículo informado realmente pertence ao contexto do jogador
---@param source number
---@param plate string|nil
---@param netId number|nil
---@param maxDistance number|nil
---@return boolean, number|nil, string|nil
function VRS.ValidateVehicleContext(source, plate, netId, maxDistance)
    local playerPed = GetPlayerPed(source)
    if not playerPed or playerPed == 0 then
        return false, nil, 'no_player'
    end

    local vehicle = nil

    if netId then
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            return false, nil, 'invalid_vehicle'
        end

        if maxDistance and not VRS.ValidateDistance(source, vehicle, maxDistance) then
            return false, nil, 'too_far'
        end
    else
        vehicle = GetVehiclePedIsIn(playerPed, false)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            return false, nil, 'invalid_vehicle'
        end
    end

    if plate and VRS.GetPlate(vehicle) ~= plate then
        return false, nil, 'plate_mismatch'
    end

    return true, vehicle, nil
end

-- Limpar cooldowns quando jogador sai
AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(playerCooldowns) do
        if key:find('^' .. src .. '_') then
            playerCooldowns[key] = nil
        end
    end
end)

-- Callback: verificar acesso à oficina
lib.callback.register('vrs_mechanic:server:hasShopAccess', function(source, shopId)
    return VRS.HasShopAccess(source, shopId)
end)

-- Callback: verificar se está em duty
lib.callback.register('vrs_mechanic:server:isOnDuty', function(source)
    return VRS.IsOnDuty(source)
end)

-- Callback: verificar se é manager
lib.callback.register('vrs_mechanic:server:isManager', function(source, shopId)
    return VRS.IsManager(source, shopId)
end)

-- Callback: dados do jogador para tablet
lib.callback.register('vrs_mechanic:server:getPlayerInfo', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    return {
        name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        citizenid = player.PlayerData.citizenid,
        job = player.PlayerData.job.name,
        grade = player.PlayerData.job.grade.level,
        gradeName = player.PlayerData.job.grade.name,
        onduty = player.PlayerData.job.onduty,
    }
end)

print('[vrs_mechanic] ^2Servidor iniciado com sucesso^0')
