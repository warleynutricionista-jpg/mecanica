-- ============================================================
-- VRS_MECHANIC - PANEL ACCESS (SERVER-SIDE VALIDATION)
-- ============================================================

-- ============================================================
-- VALIDAÇÕES DE ACESSO AO HUB
-- ============================================================

--- Verifica se o jogador tem um dos jobs de mecânico
---@param source number
---@return boolean
function VRS.IsMechanicJob(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local jobName = player.PlayerData.job.name
    for _, allowedJob in ipairs(Config.Panel.jobs) do
        if jobName == allowedJob then
            return true
        end
    end
    return false
end

--- Verifica se o jogador é boss da oficina
---@param source number
---@param shopId string
---@return boolean
function VRS.IsBoss(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or not Config.PanelAccess.bossGrades then return false end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    if player.PlayerData.job.name ~= shop.job then return false end

    local grade = player.PlayerData.job.grade.level
    for _, g in ipairs(Config.PanelAccess.bossGrades) do
        if grade >= g then return true end
    end
    return false
end

--- Retorna o nível de permissão do jogador (server-side)
---@param source number
---@return string -- 'none', 'basic', 'manager', 'boss'
function VRS.GetPermissionLevel(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 'none' end

    local jobName = player.PlayerData.job.name
    local isMechanic = false
    for _, allowedJob in ipairs(Config.Panel.jobs) do
        if jobName == allowedJob then
            isMechanic = true
            break
        end
    end
    if not isMechanic then return 'none' end

    local grade = player.PlayerData.job.grade.level

    -- Boss
    if Config.PanelAccess.bossGrades then
        for _, g in ipairs(Config.PanelAccess.bossGrades) do
            if grade >= g then return 'boss' end
        end
    end

    -- Manager
    if Config.PanelAccess.managementGrades then
        for _, g in ipairs(Config.PanelAccess.managementGrades) do
            if grade >= g then return 'manager' end
        end
    end

    return 'basic'
end

--- Valida se o jogador pode acessar o painel (server-side completo)
---@param source number
---@param panelId string
---@param shopId string|nil
---@return boolean allowed
---@return string|nil reason
function VRS.ValidatePanelAccess(source, panelId, shopId)
    -- Verificar job
    if not VRS.IsMechanicJob(source) then
        return false, 'not_mechanic'
    end

    -- Verificar duty
    if Config.Panel.requireDuty and not VRS.IsOnDuty(source) then
        return false, 'not_on_duty'
    end

    -- Verificar nível de permissão
    local permLevel = VRS.GetPermissionLevel(source)
    local panels = Config.PanelAccess.panels[permLevel]
    if not panels then
        return false, 'no_permission'
    end

    local hasAccess = false
    for _, p in ipairs(panels) do
        if p == panelId then
            hasAccess = true
            break
        end
    end

    if not hasAccess then
        return false, 'no_permission'
    end

    -- Validações específicas por painel
    if panelId == 'management' or panelId == 'settings' then
        if not shopId then
            return false, 'no_shop'
        end
        if not VRS.IsManager(source, shopId) then
            return false, 'no_permission'
        end
    end

    if panelId == 'employees' then
        if not shopId then
            return false, 'no_shop'
        end
        if not VRS.IsManager(source, shopId) then
            return false, 'no_permission'
        end
    end

    if panelId == 'stash' then
        if not shopId then
            return false, 'no_shop'
        end
        if not VRS.HasShopAccess(source, shopId) then
            return false, 'no_access'
        end
    end

    return true, nil
end

-- ============================================================
-- CALLBACKS DE VALIDAÇÃO
-- ============================================================

-- Callback: validar acesso ao hub (usado pelo client para segurança extra)
lib.callback.register('vrs_mechanic:server:validateHubAccess', function(source)
    local src = source
    if not VRS.IsMechanicJob(src) then
        return { allowed = false, reason = 'not_mechanic' }
    end
    if Config.Panel.requireDuty and not VRS.IsOnDuty(src) then
        return { allowed = false, reason = 'not_on_duty' }
    end
    return {
        allowed = true,
        permLevel = VRS.GetPermissionLevel(src),
    }
end)

-- Callback: validar acesso a um painel específico
lib.callback.register('vrs_mechanic:server:validatePanelAccess', function(source, panelId, shopId)
    local allowed, reason = VRS.ValidatePanelAccess(source, panelId, shopId)
    return { allowed = allowed, reason = reason }
end)

-- Callback: verificar se é boss
lib.callback.register('vrs_mechanic:server:isBoss', function(source, shopId)
    return VRS.IsBoss(source, shopId)
end)

-- Callback: obter nível de permissão
lib.callback.register('vrs_mechanic:server:getPermissionLevel', function(source)
    return VRS.GetPermissionLevel(source)
end)

-- ============================================================
-- LOGS DE ACESSO
-- ============================================================

-- Registrar tentativas de acesso não autorizado
RegisterNetEvent('vrs_mechanic:server:logUnauthorizedAccess', function(panelId, reason)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    local identifier = player.PlayerData.citizenid

    print(('[vrs_mechanic] ^1Acesso negado^0: %s (%s) tentou acessar painel "%s" - Razão: %s'):format(
        playerName, identifier, panelId or 'hub', reason or 'unknown'
    ))
end)
