-- ============================================================
-- VRS_MECHANIC - UPGRADES CLIENT
-- ============================================================

--- Abre menu de upgrades
---@param vehicle number
---@param shopId string
function VRS.OpenUpgradeMenu(vehicle, shopId)
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

    local options = {}

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

        options[#options + 1] = {
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

    lib.registerContext({
        id = 'vrs_upgrades',
        title = VRS.L.upgrade.title,
        description = VRS.L.upgrade.subtitle,
        menu = 'vrs_lift_menu',
        options = options,
    })

    lib.showContext('vrs_upgrades')
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
    VRS.PlayAnimation(serviceState.context.animationSet or 'upgrade_install')

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
