-- ============================================================
-- VRS_MECHANIC - REPAIRS CLIENT
-- ============================================================

--- Menu de reparo de rua
---@param vehicle number
function VRS.OpenStreetRepairMenu(vehicle)
    if not Config.StreetRepair.enabled then
        lib.notify({ title = 'Erro', description = 'Reparo de rua desativado.', type = 'error' })
        return
    end

    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_vehicle, type = 'error' })
        return
    end

    local plate = VRS.GetPlate(vehicle)
    if not plate then return end

    local status = VRS.GetLocalStatus(plate)
    if not status then return end

    local options = {}

    for _, part in ipairs(Config.StreetRepair.allowedParts) do
        local value = status[part] or 0
        local pct = VRS.GetPartPercent(part, value)
        local label = VRS.GetPartLabel(part)
        local maxPct = Config.StreetRepair.maxRecovery

        if pct >= maxPct then
            options[#options + 1] = {
                title = label,
                description = ('Já em %d%% (máx. rua: %d%%)'):format(pct, maxPct),
                icon = 'fas fa-check',
                disabled = true,
            }
        else
            -- Verificar materiais
            local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, part, true)
            local context = VRS.GetServiceContext('repair', part)

            options[#options + 1] = {
                title = label,
                description = ('Atual: %d%% → até %d%%%s%s'):format(
                    pct, maxPct,
                    context and (' | Área: %s'):format(context.serviceArea or 'geral') or '',
                    not hasMats and ' | SEM MATERIAIS' or ''
                ),
                icon = 'fas fa-wrench',
                iconColor = hasMats and '#4CAF50' or '#F44336',
                disabled = not hasMats,
                onSelect = function()
                    VRS.DoStreetRepair(vehicle, plate, part)
                end,
            }
        end
    end

    lib.registerContext({
        id = 'vrs_street_repair',
        title = VRS.L.repair.street_repair,
        description = VRS.L.repair.street_repair_desc .. (' (máx %d%%)'):format(Config.StreetRepair.maxRecovery),
        options = options,
    })

    lib.showContext('vrs_street_repair')
end

--- Executar reparo de rua
---@param vehicle number
---@param plate string
---@param part string
function VRS.DoStreetRepair(vehicle, plate, part)
    local serviceState = VRS.BeginContextualVehicleService(vehicle, nil, 'repair', part)
    if not serviceState then return end

    -- Skill check
    if Config.StreetRepair.skillCheck then
        local success = lib.skillCheck(Config.StreetRepair.skillCheck)
        if not success then
            VRS.FinishContextualVehicleService(vehicle, serviceState)
            lib.notify({ title = 'Falha', description = VRS.L.repair.skill_failed, type = 'error' })
            return
        end
    end

    -- Animação
    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'repair')

    local success = lib.progressBar({
        duration = serviceState.context.duration or Config.StreetRepair.duration or 8000,
        label = VRS.L.repair.repairing:format(VRS.GetPartLabel(part)),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.repair.failed, type = 'error' })
        return
    end

    -- Solicitar reparo ao server
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await('vrs_mechanic:server:streetRepair', false, {
        plate = plate,
        part = part,
        netId = netId,
    })

    if result and result.success then
        lib.notify({
            title = 'Reparo',
            description = VRS.L.repair.success:format(VRS.GetPartLabel(part)),
            type = 'success',
        })

        -- Aplicar efeito visual imediato
        if part == 'engine' then
            SetVehicleEngineHealth(vehicle, result.newValue)
        elseif part == 'body' then
            SetVehicleBodyHealth(vehicle, result.newValue)
            SetVehicleFixed(vehicle)
            -- Reaplicar danos de engine
            local engineVal = VRS.VehicleStatus[plate] and VRS.VehicleStatus[plate].engine or Config.MaxStatus.engine
            SetVehicleEngineHealth(vehicle, engineVal)
        end
    else
        local reason = result and result.reason or 'unknown'
        if reason == 'no_materials' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        elseif reason == 'cooldown' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.cooldown, type = 'error' })
        elseif reason == 'lift_required' then
            lib.notify({ title = 'Erro', description = 'Este reparo exige o veículo corretamente posicionado no elevador.', type = 'error' })
        elseif reason == 'lift_too_low' then
            lib.notify({ title = 'Erro', description = 'Este reparo exige o elevador acima da altura mínima.', type = 'error' })
        else
            lib.notify({ title = 'Erro', description = 'Erro no reparo.', type = 'error' })
        end
    end
end

--- Menu de reparo de oficina
---@param vehicle number
---@param shopId string
---@param menuOptions table|nil
function VRS.OpenShopRepairMenu(vehicle, shopId, menuOptions)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_vehicle, type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    if not shop then return end

    -- Verificar permissões para oficina owned
    if shop.type == 'owned' then
        if Config.ShopRepair.requireJob and not VRS.IsMechanic() then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
            return
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty() then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
            return
        end
    end

    local plate = VRS.GetPlate(vehicle)
    if not plate then return end

    local status = VRS.GetLocalStatus(plate)
    if not status then return end

    local prices = lib.callback.await('vrs_mechanic:server:getShopPrices', false, shopId)
    menuOptions = menuOptions or {}
    local parentMenuId = menuOptions.parentMenu or 'vrs_lift_menu'
    local rootMenuId = ('vrs_shop_repair_%s_%s'):format(menuOptions.liftId or shopId, plate)
    local groupedOptions = {
        quick = {},
        engine = {},
        wheel = {},
        underbody = {},
        body = {},
        finish = {},
    }

    local function pushGroup(groupKey, option)
        groupedOptions[groupKey] = groupedOptions[groupKey] or {}
        groupedOptions[groupKey][#groupedOptions[groupKey] + 1] = option
    end

    for _, part in ipairs(VRS.Parts) do
        local value = status[part] or 0
        local pct = VRS.GetPartPercent(part, value)
        local max = Config.MaxStatus[part] or 100
        local label = VRS.GetPartLabel(part)
        local price = prices[part] or 0

        if pct >= 100 then
            local option = {
                title = label,
                description = VRS.L.repair.already_full:format(label),
                icon = 'fas fa-check-circle',
                iconColor = '#4CAF50',
                disabled = true,
            }
            pushGroup('finish', option)
        else
            -- Verificar materiais
            local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, part, false)
            local context = VRS.GetServiceContext('repair', part)

            -- Listar materiais necessários
            local matsText = ''
            local mats = Config.RepairMaterials[part]
            if mats then
                local matNames = {}
                for _, m in ipairs(mats) do
                    if m.amount > 0 then
                        matNames[#matNames + 1] = ('%dx %s'):format(m.amount, VRS.GetItemLabel(m.item))
                    end
                end
                matsText = table.concat(matNames, ', ')
            end

            local color = VRS.GetStatusColor(pct)
            local iconColor = color == 'green' and '#4CAF50' or (color == 'yellow' and '#FF9800' or '#F44336')

            local option = {
                title = ('%s (%d%%)'):format(label, pct),
                description = ('Preço: R$ %s | Materiais: %s%s%s'):format(
                    VRS.FormatMoney(price),
                    matsText,
                    context and (' | Área: %s'):format(context.serviceArea or 'geral') or '',
                    not hasMats and ' | SEM MATERIAIS' or ''
                ),
                icon = 'fas fa-tools',
                iconColor = iconColor,
                disabled = not hasMats,
                onSelect = function()
                    VRS.DoShopRepair(vehicle, plate, part, shopId)
                end,
            }
            local serviceArea = context and context.serviceArea or 'body'
            local groupKey = serviceArea == 'front' and 'engine'
                or serviceArea == 'wheel' and 'wheel'
                or serviceArea == 'underbody' and 'underbody'
                or 'body'
            pushGroup(groupKey, option)
            if pct <= 40 then
                pushGroup('quick', option)
            end
        end
    end

    -- Troca de óleo separada
    if shop.services and shop.services.oil_change then
        local oilPct = VRS.GetPartPercent('oil', status.oil or 0)
        pushGroup('engine', {
            title = 'Troca de Óleo',
            description = ('Nível atual: %d%%'):format(oilPct),
            icon = 'fas fa-oil-can',
            iconColor = oilPct < 30 and '#F44336' or '#4CAF50',
            onSelect = function()
                VRS.DoOilChange(vehicle, plate, shopId)
            end,
        })
    end

    if shop.services and shop.services.wash then
        local hasCleaningKit = lib.callback.await('vrs_mechanic:server:hasItem', false, 'cleaning_kit', 1)
        pushGroup('finish', {
            title = 'Limpeza e acabamento',
            description = ('Kit de limpeza%s'):format(not hasCleaningKit and ' | SEM ITEM' or ''),
            icon = 'fas fa-soap',
            iconColor = hasCleaningKit and '#4CAF50' or '#F44336',
            disabled = not hasCleaningKit,
            onSelect = function()
                VRS.DoVehicleCleaning(vehicle, plate, shopId)
            end,
        })
    end

    local categoryDefinitions = {
        { key = 'quick', title = 'Ações rápidas', icon = 'fas fa-bolt', description = 'Itens mais urgentes para continuar o serviço.' },
        { key = 'engine', title = 'Motor / frontal', icon = 'fas fa-engine', description = 'Serviços que atuam na parte frontal e no motor.' },
        { key = 'wheel', title = 'Rodas / freios', icon = 'fas fa-circle', description = 'Serviços laterais, rodas e componentes de frenagem.' },
        { key = 'underbody', title = 'Parte inferior', icon = 'fas fa-car-rear', description = 'Componentes acessados por baixo do veículo.' },
        { key = 'body', title = 'Estrutura geral', icon = 'fas fa-car', description = 'Serviços gerais de carroceria e componentes sem grupo específico.' },
        { key = 'finish', title = 'Finalização', icon = 'fas fa-sparkles', description = 'Itens concluídos ou acabamento final.' },
    }

    local rootOptions = {
        {
            title = menuOptions.liftName and ('Elevador: %s'):format(menuOptions.liftName) or 'Elevador ativo',
            description = ('Veículo: %s'):format(plate),
            icon = 'fas fa-elevator',
            readOnly = true,
        },
    }

    for _, category in ipairs(categoryDefinitions) do
        local categoryOptions = groupedOptions[category.key] or {}
        if #categoryOptions > 0 then
            local categoryMenuId = ('%s_%s'):format(rootMenuId, category.key)
            lib.registerContext({
                id = categoryMenuId,
                title = category.title,
                menu = rootMenuId,
                options = categoryOptions,
            })

            rootOptions[#rootOptions + 1] = {
                title = category.title,
                description = ('%s (%d opções)'):format(category.description, #categoryOptions),
                icon = category.icon,
                menu = categoryMenuId,
            }
        end
    end

    lib.registerContext({
        id = rootMenuId,
        title = VRS.L.repair.shop_repair,
        description = VRS.L.repair.shop_repair_desc,
        menu = parentMenuId,
        options = rootOptions,
    })

    lib.showContext(rootMenuId)
end

--- Executar reparo de oficina
---@param vehicle number
---@param plate string
---@param part string
---@param shopId string
function VRS.DoShopRepair(vehicle, plate, part, shopId)
    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'repair', part)
    if not serviceState then return end

    -- Skill check
    if Config.ShopRepair.skillCheck then
        local success = lib.skillCheck(Config.ShopRepair.skillCheck)
        if not success then
            VRS.FinishContextualVehicleService(vehicle, serviceState)
            lib.notify({ title = 'Falha', description = VRS.L.repair.skill_failed, type = 'error' })
            return
        end
    end

    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'repair')

    local success = lib.progressBar({
        duration = serviceState.context.duration or Config.ShopRepair.duration or 12000,
        label = VRS.L.repair.repairing:format(VRS.GetPartLabel(part)),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.repair.failed, type = 'error' })
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await('vrs_mechanic:server:repairPart', false, {
        plate = plate,
        part = part,
        shopId = shopId,
        netId = netId,
    })

    if result and result.success then
        lib.notify({
            title = 'Reparo',
            description = VRS.L.repair.success:format(VRS.GetPartLabel(part)),
            type = 'success',
        })

        -- Aplicar efeito visual
        if part == 'engine' then
            SetVehicleEngineHealth(vehicle, result.newValue)
        elseif part == 'body' then
            SetVehicleBodyHealth(vehicle, result.newValue)
            SetVehicleFixed(vehicle)
            local engineVal = VRS.VehicleStatus[plate] and VRS.VehicleStatus[plate].engine or Config.MaxStatus.engine
            SetVehicleEngineHealth(vehicle, engineVal)
        end
    else
        local reason = result and result.reason or 'unknown'
        if reason == 'no_materials' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        elseif reason == 'cooldown' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.cooldown, type = 'error' })
        elseif reason == 'not_on_duty' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
        elseif reason == 'no_access' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
        elseif reason == 'lift_required' then
            lib.notify({ title = 'Erro', description = 'Este reparo exige o veículo corretamente posicionado no elevador.', type = 'error' })
        elseif reason == 'lift_too_low' then
            lib.notify({ title = 'Erro', description = 'Elevador muito baixo para acessar este componente.', type = 'error' })
        else
            lib.notify({ title = 'Erro', description = 'Erro no reparo.', type = 'error' })
        end
    end
end

--- Troca de óleo
---@param vehicle number
---@param plate string
---@param shopId string
function VRS.DoOilChange(vehicle, plate, shopId)
    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'repair', 'oil')
    if not serviceState then return end

    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'repair')

    local success = lib.progressBar({
        duration = serviceState.context.duration or 6000,
        label = 'Trocando óleo...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.repair.failed, type = 'error' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:changeOil', false, {
        plate = plate,
        shopId = shopId,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
    })

    if result and result.success then
        lib.notify({
            title = 'Troca de Óleo',
            description = 'Óleo trocado com sucesso!',
            type = 'success',
        })
    else
        local reason = result and result.reason or 'unknown'
        if reason == 'no_materials' then
            lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        elseif reason == 'lift_required' then
            lib.notify({ title = 'Erro', description = 'A troca de óleo exige o veículo corretamente posicionado.', type = 'error' })
        elseif reason == 'lift_too_low' then
            lib.notify({ title = 'Erro', description = 'Elevador muito baixo para acessar a parte inferior necessária.', type = 'error' })
        else
            lib.notify({ title = 'Erro', description = 'Erro na troca de óleo.', type = 'error' })
        end
    end
end

function VRS.DoVehicleCleaning(vehicle, plate, shopId)
    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'repair', 'cleaning')
    if not serviceState then return end

    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'cleaning')

    local success = lib.progressBar({
        duration = serviceState.context.duration or 9000,
        label = 'Limpando e finalizando o veículo...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = 'A limpeza foi interrompida.', type = 'error' })
        return
    end

    local removed = lib.callback.await('vrs_mechanic:server:removeItem', false, 'cleaning_kit', 1)
    if not removed then
        lib.notify({ title = 'Erro', description = 'Você precisa de um kit de limpeza para concluir este serviço.', type = 'error' })
        return
    end

    SetVehicleDirtLevel(vehicle, 0.0)
    WashDecalsFromVehicle(vehicle, 1.0)

    lib.notify({ title = 'Limpeza', description = 'Limpeza concluída com acabamento profissional.', type = 'success' })
end
