-- ============================================================
-- VRS_MECHANIC - UPGRADES CLIENT
-- ============================================================

--- Abre menu de upgrades
---@param vehicle number
---@param shopId string
---@param menuOptions table|nil
function VRS.OpenUpgradeMenu(vehicle, shopId, menuOptions)
    if not Config.Upgrades.enabled then
        lib.notify({ title = 'Erro', description = 'Upgrades desativados.', type = 'error' })
        return
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_vehicle, type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    if not shop or not shop.services or not shop.services.upgrades then
        lib.notify({ title = 'Erro', description = 'Esta oficina não realiza upgrades.', type = 'error' })
        return
    end

    if Config.Upgrades.requireJob and not VRS.IsMechanic() then
        lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
        return
    end

    if Config.Upgrades.requireDuty and not VRS.IsOnDuty() then
        lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
        return
    end

    menuOptions = menuOptions or {}
    local parentMenuId = menuOptions.parentMenu or 'vrs_lift_menu'
    local plate = VRS.GetPlate(vehicle) or 'SEMPLACA'
    local rootMenuId = ('vrs_upgrades_%s_%s'):format(menuOptions.liftId or shopId, plate)
    local groupedOptions = {
        powertrain = {},
        electronics = {},
        boost = {},
        misc = {},
    }

    local function getUpgradeGroup(upgradeType)
        local lower = tostring(upgradeType):lower()
        if lower:find('ecu', 1, true) then
            return 'electronics'
        end
        if lower:find('turbo', 1, true) or lower:find('nitro', 1, true) then
            return 'boost'
        end
        if lower:find('engine', 1, true) or lower:find('trans', 1, true) or lower:find('clutch', 1, true) then
            return 'powertrain'
        end
        return 'misc'
    end

    for _, upgradeType in ipairs(VRS.UpgradeTypes) do
        local label = VRS.L.upgrade[upgradeType] or upgradeType
        local materials = Config.UpgradeMaterials[upgradeType]
        local context = VRS.GetServiceContext('upgrade', upgradeType)

        -- Verificar materiais
        local hasMats = true
        local matsText = ''
        if materials then
            local matNames = {}
            for _, m in ipairs(materials) do
                if m.amount > 0 then
                    local count = lib.callback.await('vrs_mechanic:server:hasItem', false, m.item, m.amount)
                    if not count then hasMats = false end
                    matNames[#matNames + 1] = ('%dx %s'):format(m.amount, VRS.GetItemLabel(m.item))
                end
            end
            matsText = table.concat(matNames, ', ')
        end

        groupedOptions[getUpgradeGroup(upgradeType)][#groupedOptions[getUpgradeGroup(upgradeType)] + 1] = {
            title = label,
            description = ('Materiais: %s%s%s'):format(
                matsText,
                context and (' | Área: %s'):format(context.serviceArea or 'geral') or '',
                not hasMats and ' | SEM MATERIAIS' or ''
            ),
            icon = 'fas fa-bolt',
            iconColor = hasMats and '#4CAF50' or '#F44336',
            disabled = not hasMats,
            onSelect = function()
                VRS.InstallUpgrade(vehicle, upgradeType, shopId)
            end,
        }
    end

    local rootOptions = {
        {
            title = menuOptions.liftName and ('Elevador: %s'):format(menuOptions.liftName) or 'Elevador ativo',
            description = ('Veículo: %s'):format(plate),
            icon = 'fas fa-elevator',
            readOnly = true,
        },
    }

    local categories = {
        { key = 'powertrain', title = 'Powertrain', icon = 'fas fa-engine', description = 'Motor, transmissão e componentes principais.' },
        { key = 'electronics', title = 'Eletrônica', icon = 'fas fa-microchip', description = 'ECU e ajustes eletrônicos.' },
        { key = 'boost', title = 'Turbo / nitro', icon = 'fas fa-gauge-high', description = 'Sistemas de pressão e ganho extra.' },
        { key = 'misc', title = 'Outros upgrades', icon = 'fas fa-bolt', description = 'Itens adicionais e complementares.' },
    }

    for _, category in ipairs(categories) do
        local options = groupedOptions[category.key]
        if options and #options > 0 then
            local categoryMenuId = ('%s_%s'):format(rootMenuId, category.key)
            lib.registerContext({
                id = categoryMenuId,
                title = category.title,
                menu = rootMenuId,
                options = options,
            })

            rootOptions[#rootOptions + 1] = {
                title = category.title,
                description = ('%s (%d opções)'):format(category.description, #options),
                icon = category.icon,
                menu = categoryMenuId,
            }
        end
    end

    lib.registerContext({
        id = rootMenuId,
        title = VRS.L.upgrade.title,
        description = VRS.L.upgrade.subtitle,
        menu = parentMenuId,
        options = rootOptions,
    })

    lib.showContext(rootMenuId)
end

--- Instalar upgrade
---@param vehicle number
---@param upgradeType string
---@param shopId string
function VRS.InstallUpgrade(vehicle, upgradeType, shopId)
    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'upgrade', upgradeType)
    if not serviceState then return end

    -- Skill check
    if Config.Upgrades.skillCheck then
        local success = lib.skillCheck(Config.Upgrades.skillCheck)
        if not success then
            VRS.FinishContextualVehicleService(vehicle, serviceState)
            lib.notify({ title = 'Falha', description = VRS.L.repair.skill_failed, type = 'error' })
            return
        end
    end

    local label = VRS.L.upgrade[upgradeType] or upgradeType
    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'upgrade_install')

    local success = lib.progressBar({
        duration = serviceState.context.duration or Config.Upgrades.duration or 15000,
        label = VRS.L.upgrade.installing:format(label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.upgrade.failed, type = 'error' })
        return
    end

    -- Consumir materiais no server
    local result = lib.callback.await('vrs_mechanic:server:installUpgrade', false, {
        plate = VRS.GetPlate(vehicle),
        upgradeType = upgradeType,
        shopId = shopId,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    })

    if result and result.success then
        -- Aplicar mod GTA
        local modInfo = VRS.UpgradeModIndex[upgradeType]
        if modInfo then
            SetVehicleModKit(vehicle, 0)
            SetVehicleMod(vehicle, modInfo.modType, modInfo.modIndex, false)
        end

        lib.notify({
            title = 'Upgrade',
            description = VRS.L.upgrade.success:format(label),
            type = 'success',
        })
    else
        local reason = result and result.reason or 'unknown'
        if reason == 'no_materials' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        elseif reason == 'lift_required' then
            lib.notify({ title = 'Erro', description = 'Este upgrade exige o veículo no elevador.', type = 'error' })
        elseif reason == 'lift_too_low' then
            lib.notify({ title = 'Erro', description = 'Elevador muito baixo para este upgrade.', type = 'error' })
        else
            lib.notify({ title = 'Erro', description = 'Erro na instalação.', type = 'error' })
        end
    end
end
