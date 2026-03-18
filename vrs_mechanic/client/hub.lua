-- ============================================================
-- VRS_MECHANIC - HUB F12 (PAINEL CENTRAL DA MECÂNICA)
-- ============================================================

-- ============================================================
-- ESTADO INTERNO
-- ============================================================

local HubState = {
    hubOpen = false,
    tabletOpen = false,
    busy = false,
    lastOpenTime = 0,
    currentShop = nil,
    permissionLevel = 'none', -- 'none', 'basic', 'manager', 'boss'
}

-- ============================================================
-- HELPERS DE VALIDAÇÃO (CLIENT-SIDE)
-- ============================================================

--- Verifica se o jogador tem um dos jobs permitidos
---@return boolean
local function isAllowedJob()
    local job = QBX.PlayerData.job
    if not job then return false end
    for _, allowedJob in ipairs(Config.Panel.jobs) do
        if job.name == allowedJob then
            return true
        end
    end
    return false
end

--- Retorna o nível de permissão do jogador
---@return string -- 'none', 'basic', 'manager', 'boss'
local function getPermissionLevel()
    local job = QBX.PlayerData.job
    if not job then return 'none' end

    if not isAllowedJob() then return 'none' end

    local grade = job.grade and job.grade.level or 0

    -- Verificar boss
    if Config.PanelAccess.bossGrades then
        for _, g in ipairs(Config.PanelAccess.bossGrades) do
            if grade >= g then return 'boss' end
        end
    end

    -- Verificar manager
    if Config.PanelAccess.managementGrades then
        for _, g in ipairs(Config.PanelAccess.managementGrades) do
            if grade >= g then return 'manager' end
        end
    end

    return 'basic'
end

--- Verifica se o jogador está em estado inválido
---@return boolean canOpen
---@return string|nil reason
local function canOpenHub()
    local ped = cache.ped

    -- Job check
    if not isAllowedJob() then
        return false, 'blocked_not_mechanic'
    end

    -- Duty check
    if Config.Panel.requireDuty then
        local job = QBX.PlayerData.job
        if not job or not job.onduty then
            return false, 'blocked_not_on_duty'
        end
    end

    -- Morto / incapacitado
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        return false, 'blocked_dead'
    end

    -- Ragdoll
    if IsPedRagdoll(ped) then
        return false, 'blocked_invalid_state'
    end

    -- Caído / incapacitado (QBX laststand)
    if LocalPlayer.state.dead or LocalPlayer.state.laststand or LocalPlayer.state.handcuffed then
        return false, 'blocked_invalid_state'
    end

    -- Dentro de veículo
    if not Config.Panel.allowInVehicle and cache.vehicle then
        return false, 'blocked_in_vehicle'
    end

    -- Pause menu ativo
    if Config.Panel.blockOnPauseMenu and IsPauseMenuActive() then
        return false, 'blocked_invalid_state'
    end

    -- Cooldown
    local now = GetGameTimer()
    if (now - HubState.lastOpenTime) < Config.Panel.openCooldown then
        return false, 'blocked_cooldown'
    end

    -- HUB já aberto / busy
    if HubState.busy then
        return false, 'blocked_busy'
    end

    return true, nil
end

--- Verifica se um painel está disponível para o nível de permissão atual
---@param panelId string
---@param permLevel string
---@return boolean
local function hasPanelAccess(panelId, permLevel)
    local panels = Config.PanelAccess.panels[permLevel]
    if not panels then return false end
    for _, p in ipairs(panels) do
        if p == panelId then return true end
    end
    return false
end

--- Retorna o shopId contextual (zona ou job)
---@return string|nil
local function getContextShop()
    -- Priorizar zona atual
    if VRS.CurrentShop then
        return VRS.CurrentShop
    end
    -- Fallback: shopId pelo job
    return VRS.GetPlayerShopId()
end

--- Verifica se há veículo próximo
---@return number|nil vehicle
local function getNearbyVehicle()
    local vehicle = VRS.GetClosestVehicle(5.0)
    return vehicle
end

-- ============================================================
-- MONTAGEM DO MENU HUB
-- ============================================================

--- Monta as opções do HUB baseado no contexto e permissão
---@return table options
local function buildHubOptions()
    local options = {}
    local permLevel = getPermissionLevel()
    local shopId = getContextShop()
    local inShop = VRS.InShopZone
    local nearVehicle = getNearbyVehicle()
    local shop = shopId and Config.Shops[shopId] or nil

    HubState.permissionLevel = permLevel
    HubState.currentShop = shopId

    local L = VRS.L.hub

    -- Tablet (requer oficina owned)
    if hasPanelAccess('tablet', permLevel) and shop and shop.type == 'owned' then
        options[#options + 1] = {
            title = L.open_tablet,
            description = L.open_tablet_desc,
            icon = 'fas fa-tablet-alt',
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenTablet(shopId)
            end,
        }
    end

    -- Diagnóstico rápido (requer veículo próximo)
    if hasPanelAccess('diagnostic', permLevel) and nearVehicle then
        options[#options + 1] = {
            title = L.diagnostic,
            description = L.diagnostic_desc,
            icon = 'fas fa-stethoscope',
            iconColor = '#2196F3',
            onSelect = function()
                HubState.hubOpen = false
                if inShop and shopId then
                    VRS.FullDiagnostic(nearVehicle, shopId)
                else
                    VRS.QuickDiagnostic(nearVehicle)
                end
            end,
        }
    end

    -- Ordens de serviço (requer oficina)
    if hasPanelAccess('work_orders', permLevel) and shopId then
        options[#options + 1] = {
            title = L.work_orders,
            description = L.work_orders_desc,
            icon = 'fas fa-clipboard-list',
            iconColor = '#FF9800',
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenWorkOrdersMenu(shopId)
            end,
        }
    end

    -- Cobrança (requer jogador próximo)
    if hasPanelAccess('billing', permLevel) then
        options[#options + 1] = {
            title = L.billing,
            description = L.billing_desc,
            icon = 'fas fa-file-invoice-dollar',
            iconColor = '#4CAF50',
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenBillingMenu(shopId)
            end,
        }
    end

    -- Serviços rápidos (requer veículo próximo)
    if hasPanelAccess('quick_services', permLevel) and nearVehicle then
        options[#options + 1] = {
            title = L.quick_services,
            description = L.quick_services_desc,
            icon = 'fas fa-bolt',
            iconColor = '#FF5722',
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenQuickServicesMenu(nearVehicle, shopId)
            end,
        }
    end

    -- Funcionários (requer manager+ e oficina)
    if hasPanelAccess('employees', permLevel) then
        local blocked = not inShop and not Config.Panel.allowManagementOutsideShop
        options[#options + 1] = {
            title = L.employees,
            description = blocked and L.blocked_management_outside or L.employees_desc,
            icon = 'fas fa-users',
            iconColor = '#9C27B0',
            disabled = blocked,
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenEmployeesMenu(shopId)
            end,
        }
    end

    -- Gestão da oficina (requer boss e oficina)
    if hasPanelAccess('management', permLevel) then
        local blocked = not inShop and not Config.Panel.allowManagementOutsideShop
        options[#options + 1] = {
            title = L.management,
            description = blocked and L.blocked_management_outside or L.management_desc,
            icon = 'fas fa-building',
            iconColor = '#3F51B5',
            disabled = blocked,
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenManagementHub(shopId)
            end,
        }
    end

    -- Estoque (requer estar na oficina)
    if hasPanelAccess('stash', permLevel) and shopId then
        local blocked = not inShop
        options[#options + 1] = {
            title = L.stash,
            description = blocked and L.blocked_no_shop or L.stash_desc,
            icon = 'fas fa-boxes',
            iconColor = '#795548',
            disabled = blocked,
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenStash(shopId)
            end,
        }
    end

    -- Configurações (boss only)
    if hasPanelAccess('settings', permLevel) and shopId then
        local blocked = not inShop and not Config.Panel.allowManagementOutsideShop
        options[#options + 1] = {
            title = L.settings,
            description = blocked and L.blocked_management_outside or L.settings_desc,
            icon = 'fas fa-cog',
            iconColor = '#607D8B',
            disabled = blocked,
            onSelect = function()
                HubState.hubOpen = false
                VRS.OpenSettingsMenu(shopId)
            end,
        }
    end

    -- Fechar
    options[#options + 1] = {
        title = L.close,
        description = L.close_desc,
        icon = 'fas fa-times',
        iconColor = '#F44336',
        onSelect = function()
            HubState.hubOpen = false
        end,
    }

    return options
end

-- ============================================================
-- ABRIR / FECHAR HUB
-- ============================================================

--- Abre o HUB central da mecânica
function VRS.OpenHub()
    -- Se o tablet estiver aberto, comportamento configurável
    if HubState.tabletOpen then
        VRS.CloseTablet()
        if Config.Panel.tabletToggleBehavior == 'close' then
            return
        end
    end

    local canOpen, reason = canOpenHub()
    if not canOpen then
        if reason then
            lib.notify({
                title = VRS.L.hub.title,
                description = VRS.L.hub[reason] or VRS.L.hub.blocked_invalid_state,
                type = 'error',
                duration = 3000,
            })
        end
        return
    end

    HubState.lastOpenTime = GetGameTimer()
    HubState.hubOpen = true

    local options = buildHubOptions()
    local shopId = HubState.currentShop
    local shop = shopId and Config.Shops[shopId] or nil
    local L = VRS.L.hub

    -- Subtítulo contextual
    local subtitle = L.subtitle
    if VRS.InShopZone and shop then
        subtitle = L.context_inside .. ' - ' .. shop.label
    elseif not VRS.InShopZone then
        subtitle = L.context_outside
    end

    lib.registerContext({
        id = 'vrs_mechanic_hub',
        title = L.title,
        description = subtitle,
        options = options,
        onClose = function()
            HubState.hubOpen = false
        end,
    })

    lib.showContext('vrs_mechanic_hub')
end

--- Fecha o HUB
function VRS.CloseHub()
    if HubState.hubOpen then
        lib.hideContext(false)
        HubState.hubOpen = false
    end
end

-- ============================================================
-- SUBMENUS ACESSADOS PELO HUB
-- ============================================================

--- Menu de Ordens de Serviço (via contexto)
---@param shopId string
function VRS.OpenWorkOrdersMenu(shopId)
    if not shopId then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.hub.blocked_no_shop, type = 'error' })
        return
    end

    -- Validar no server
    local orders = lib.callback.await('vrs_mechanic:server:getWorkOrders', false, shopId)
    if not orders or #orders == 0 then
        lib.notify({ title = VRS.L.work_order.title, description = VRS.L.work_order.no_orders, type = 'inform' })
        return
    end

    local options = {}
    for _, order in ipairs(orders) do
        local statusLabel = VRS.L.work_order['status_' .. order.status] or order.status
        local iconColor = '#FF9800'
        if order.status == 'done' or order.status == 'delivered' then
            iconColor = '#4CAF50'
        elseif order.status == 'open' then
            iconColor = '#2196F3'
        end

        options[#options + 1] = {
            title = VRS.L.work_order.id:format(order.id),
            description = ('%s | %s | %s'):format(
                order.plate or '---',
                order.model or '---',
                statusLabel
            ),
            icon = 'fas fa-file-alt',
            iconColor = iconColor,
            metadata = {
                { label = VRS.L.work_order.owner, value = order.owner_name or '---' },
                { label = VRS.L.work_order.mechanic, value = order.mechanic_name or '---' },
                { label = VRS.L.work_order.budget, value = ('R$ %s'):format(VRS.FormatMoney(order.budget or 0)) },
            },
        }
    end

    lib.registerContext({
        id = 'vrs_hub_work_orders',
        title = VRS.L.work_order.title,
        menu = 'vrs_mechanic_hub',
        options = options,
    })

    lib.showContext('vrs_hub_work_orders')
end

--- Menu de Cobrança
---@param shopId string|nil
function VRS.OpenBillingMenu(shopId)
    local input = lib.inputDialog(VRS.L.billing.title, {
        { type = 'number', label = VRS.L.billing.amount, min = Config.Billing.minAmount, max = Config.Billing.maxAmount, required = true },
        { type = 'input', label = VRS.L.billing.description, placeholder = 'Serviço realizado', required = false },
    })

    if not input then return end

    local amount = tonumber(input[1])
    if not amount or amount < Config.Billing.minAmount or amount > Config.Billing.maxAmount then
        lib.notify({ title = VRS.L.billing.title, description = VRS.L.billing.invalid_amount, type = 'error' })
        return
    end

    -- Buscar jogadores próximos
    local nearby = lib.callback.await('vrs_mechanic:server:getNearbyPlayers', false)
    if not nearby or #nearby == 0 then
        lib.notify({ title = VRS.L.billing.title, description = VRS.L.billing.no_player, type = 'error' })
        return
    end

    local playerOptions = {}
    for _, p in ipairs(nearby) do
        playerOptions[#playerOptions + 1] = {
            title = p.name,
            description = ('ID: %d'):format(p.id),
            icon = 'fas fa-user',
            onSelect = function()
                local result = lib.callback.await('vrs_mechanic:server:sendBill', false, {
                    amount = amount,
                    targetId = p.id,
                    shopId = shopId,
                    description = input[2] or 'Serviço mecânico',
                })
                if result and result.success then
                    lib.notify({
                        title = VRS.L.billing.title,
                        description = VRS.L.billing.success:format(VRS.FormatMoney(amount)),
                        type = 'success',
                    })
                else
                    local reason = result and result.reason or 'error'
                    if reason == 'target_insufficient' then
                        lib.notify({ title = VRS.L.billing.title, description = VRS.L.billing.insufficient, type = 'error' })
                    else
                        lib.notify({ title = VRS.L.billing.title, description = VRS.L.billing.invalid_amount, type = 'error' })
                    end
                end
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_hub_billing_targets',
        title = VRS.L.billing.send,
        menu = 'vrs_mechanic_hub',
        options = playerOptions,
    })

    lib.showContext('vrs_hub_billing_targets')
end

--- Menu de Serviços Rápidos
---@param vehicle number
---@param shopId string|nil
function VRS.OpenQuickServicesMenu(vehicle, shopId)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.hub.blocked_no_vehicle, type = 'error' })
        return
    end

    local L = VRS.L.hub
    local options = {}

    -- Reparo rápido
    options[#options + 1] = {
        title = L.quick_repair,
        description = L.quick_repair_desc,
        icon = 'fas fa-tools',
        iconColor = '#FF5722',
        onSelect = function()
            if VRS.InShopZone and shopId then
                VRS.OpenShopRepairMenu(vehicle, shopId)
            else
                VRS.OpenStreetRepairMenu(vehicle)
            end
        end,
    }

    -- Troca de óleo
    if shopId and VRS.InShopZone then
        local shop = Config.Shops[shopId]
        if shop and shop.services and shop.services.oil_change then
            local plate = VRS.GetPlate(vehicle)
            options[#options + 1] = {
                title = L.quick_oil,
                description = L.quick_oil_desc,
                icon = 'fas fa-oil-can',
                iconColor = '#FFC107',
                onSelect = function()
                    if plate then
                        VRS.DoOilChange(vehicle, plate, shopId)
                    end
                end,
            }
        end
    end

    -- Troca de pneu
    options[#options + 1] = {
        title = L.quick_tyre,
        description = L.quick_tyre_desc,
        icon = 'fas fa-circle',
        iconColor = '#424242',
        onSelect = function()
            if shopId then
                VRS.OpenTyreMenu(vehicle, shopId)
            end
        end,
    }

    lib.registerContext({
        id = 'vrs_hub_quick_services',
        title = L.quick_services,
        menu = 'vrs_mechanic_hub',
        options = options,
    })

    lib.showContext('vrs_hub_quick_services')
end

--- Menu de Funcionários (via HUB)
---@param shopId string
function VRS.OpenEmployeesMenu(shopId)
    if not shopId then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.hub.blocked_no_shop, type = 'error' })
        return
    end

    -- Validar permissão no server
    local isManager = lib.callback.await('vrs_mechanic:server:isManager', false, shopId)
    if not isManager then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.notify.no_permission, type = 'error' })
        return
    end

    local employees = lib.callback.await('vrs_mechanic:server:getEmployees', false, shopId)
    if not employees or #employees == 0 then
        lib.notify({ title = VRS.L.management.employees, description = 'Nenhum funcionário registrado.', type = 'inform' })
        return
    end

    local options = {}
    for _, emp in ipairs(employees) do
        local status = emp.online and VRS.L.management.online or VRS.L.management.offline
        options[#options + 1] = {
            title = emp.name,
            description = ('Grade: %d | %s'):format(emp.grade, status),
            icon = emp.online and 'fas fa-user-check' or 'fas fa-user-times',
            iconColor = emp.online and '#4CAF50' or '#9E9E9E',
        }
    end

    lib.registerContext({
        id = 'vrs_hub_employees',
        title = VRS.L.management.employees,
        menu = 'vrs_mechanic_hub',
        options = options,
    })

    lib.showContext('vrs_hub_employees')
end

--- Menu de Gestão da Oficina (HUB administrativo)
---@param shopId string
function VRS.OpenManagementHub(shopId)
    if not shopId then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.hub.blocked_no_shop, type = 'error' })
        return
    end

    -- Validar permissão no server
    local isManager = lib.callback.await('vrs_mechanic:server:isManager', false, shopId)
    if not isManager then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.notify.no_permission, type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    local stats = lib.callback.await('vrs_mechanic:server:getShopStats', false, shopId)
    local L = VRS.L

    local options = {}

    -- Estatísticas
    if stats then
        options[#options + 1] = {
            title = L.management.revenue,
            description = ('R$ %s'):format(VRS.FormatMoney(stats.revenue or 0)),
            icon = 'fas fa-chart-line',
            iconColor = '#4CAF50',
            readOnly = true,
        }
        options[#options + 1] = {
            title = L.management.total_orders,
            description = tostring(stats.totalOrders or 0),
            icon = 'fas fa-clipboard-list',
            readOnly = true,
        }
        options[#options + 1] = {
            title = L.management.completed_orders,
            description = tostring(stats.completedOrders or 0),
            icon = 'fas fa-check-double',
            iconColor = '#4CAF50',
            readOnly = true,
        }
    end

    -- Funcionários
    options[#options + 1] = {
        title = L.management.employees,
        description = ('Total: %d'):format(stats and stats.employeeCount or 0),
        icon = 'fas fa-users',
        iconColor = '#9C27B0',
        onSelect = function()
            VRS.OpenEmployeesMenu(shopId)
        end,
    }

    -- Preços
    options[#options + 1] = {
        title = L.management.pricing,
        description = L.hub.settings_prices_desc,
        icon = 'fas fa-tags',
        iconColor = '#FF9800',
        onSelect = function()
            VRS.OpenPricingMenu(shopId)
        end,
    }

    -- Histórico
    options[#options + 1] = {
        title = L.hub.settings_logs,
        description = L.hub.settings_logs_desc,
        icon = 'fas fa-history',
        iconColor = '#607D8B',
        onSelect = function()
            VRS.OpenBillingHistoryMenu(shopId)
        end,
    }

    lib.registerContext({
        id = 'vrs_hub_management',
        title = L.management.title:format(shop and shop.label or 'Oficina'),
        menu = 'vrs_mechanic_hub',
        options = options,
    })

    lib.showContext('vrs_hub_management')
end

--- Menu de Preços
---@param shopId string
function VRS.OpenPricingMenu(shopId)
    local isManager = lib.callback.await('vrs_mechanic:server:isManager', false, shopId)
    if not isManager then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.notify.no_permission, type = 'error' })
        return
    end

    local prices = lib.callback.await('vrs_mechanic:server:getShopPrices', false, shopId)
    if not prices then return end

    local options = {}
    for _, part in ipairs(VRS.Parts) do
        local label = VRS.GetPartLabel(part)
        local price = prices[part] or 0
        options[#options + 1] = {
            title = label,
            description = ('R$ %s'):format(VRS.FormatMoney(price)),
            icon = 'fas fa-tag',
            onSelect = function()
                local input = lib.inputDialog(('Preço: %s'):format(label), {
                    { type = 'number', label = 'Novo preço', default = price, min = 0, required = true },
                })
                if input and input[1] then
                    local result = lib.callback.await('vrs_mechanic:server:updatePrice', false, shopId, part, input[1])
                    if result and result.success then
                        lib.notify({ title = VRS.L.management.pricing, description = VRS.L.management.price_updated, type = 'success' })
                    end
                end
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_hub_pricing',
        title = VRS.L.management.pricing,
        menu = 'vrs_hub_management',
        options = options,
    })

    lib.showContext('vrs_hub_pricing')
end

--- Menu de Histórico de Faturamento
---@param shopId string
function VRS.OpenBillingHistoryMenu(shopId)
    local history = lib.callback.await('vrs_mechanic:server:getBillingHistory', false, shopId)
    if not history or #history == 0 then
        lib.notify({ title = VRS.L.hub.settings_logs, description = 'Nenhum registro encontrado.', type = 'inform' })
        return
    end

    local options = {}
    for _, entry in ipairs(history) do
        options[#options + 1] = {
            title = ('R$ %s'):format(VRS.FormatMoney(entry.amount or 0)),
            description = ('%s → %s | %s'):format(
                entry.mechanic_name or '---',
                entry.customer_name or '---',
                entry.description or ''
            ),
            icon = 'fas fa-receipt',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'vrs_hub_billing_history',
        title = VRS.L.hub.settings_logs,
        menu = 'vrs_hub_management',
        options = options,
    })

    lib.showContext('vrs_hub_billing_history')
end

--- Menu de Configurações (boss only)
---@param shopId string
function VRS.OpenSettingsMenu(shopId)
    if not shopId then return end

    -- Validar boss no server
    local isBoss = lib.callback.await('vrs_mechanic:server:isBoss', false, shopId)
    if not isBoss then
        lib.notify({ title = VRS.L.hub.title, description = VRS.L.notify.no_permission, type = 'error' })
        return
    end

    local L = VRS.L.hub
    local options = {}

    -- Preços
    options[#options + 1] = {
        title = L.settings_prices,
        description = L.settings_prices_desc,
        icon = 'fas fa-tags',
        iconColor = '#FF9800',
        onSelect = function()
            VRS.OpenPricingMenu(shopId)
        end,
    }

    -- Logs
    options[#options + 1] = {
        title = L.settings_logs,
        description = L.settings_logs_desc,
        icon = 'fas fa-history',
        iconColor = '#607D8B',
        onSelect = function()
            VRS.OpenBillingHistoryMenu(shopId)
        end,
    }

    lib.registerContext({
        id = 'vrs_hub_settings',
        title = L.settings,
        menu = 'vrs_mechanic_hub',
        options = options,
    })

    lib.showContext('vrs_hub_settings')
end

-- ============================================================
-- KEYBIND F12
-- ============================================================

lib.addKeybind({
    name = 'vrs_mechanic_hub_f12',
    description = Config.Panel.description or 'HUB Mecânica',
    defaultKey = Config.Panel.key or 'F12',
    onPressed = function()
        VRS.OpenHub()
    end,
})

-- ============================================================
-- SINCRONIZAÇÃO DE ESTADO DO TABLET
-- ============================================================

-- Hook no sistema de tablet existente para rastrear estado
local _origOpenTablet = VRS.OpenTablet
local _origCloseTablet = VRS.CloseTablet

-- Sobrescrever OpenTablet para rastrear estado no HubState
local function hookTabletOpen(shopId)
    HubState.tabletOpen = true
    HubState.busy = true
    if _origOpenTablet then
        _origOpenTablet(shopId)
    end
end

local function hookTabletClose()
    HubState.tabletOpen = false
    HubState.busy = false
    if _origCloseTablet then
        _origCloseTablet()
    end
end

-- Aplicar hooks após o carregamento completo
CreateThread(function()
    Wait(500) -- Aguardar todos os scripts carregarem

    -- Re-capturar as funções originais (podem ter sido definidas depois)
    if VRS.OpenTablet and VRS.OpenTablet ~= hookTabletOpen then
        _origOpenTablet = VRS.OpenTablet
    end
    if VRS.CloseTablet and VRS.CloseTablet ~= hookTabletClose then
        _origCloseTablet = VRS.CloseTablet
    end

    VRS.OpenTablet = hookTabletOpen
    VRS.CloseTablet = hookTabletClose
end)

-- ============================================================
-- EXPORTS
-- ============================================================

exports('OpenMechanicHub', function()
    VRS.OpenHub()
end)

exports('IsHubOpen', function()
    return HubState.hubOpen
end)

exports('GetHubState', function()
    return HubState
end)
