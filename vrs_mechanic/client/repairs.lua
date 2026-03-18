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

            options[#options + 1] = {
                title = label,
                description = ('Atual: %d%% → até %d%% %s'):format(
                    pct, maxPct,
                    not hasMats and '| SEM MATERIAIS' or ''
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
    -- Skill check
    if Config.StreetRepair.skillCheck then
        local success = lib.skillCheck(Config.StreetRepair.skillCheck)
        if not success then
            lib.notify({ title = 'Falha', description = VRS.L.repair.skill_failed, type = 'error' })
            return
        end
    end

    -- Animação
    VRS.PlayAnimation('repair')

    local success = lib.progressBar({
        duration = Config.StreetRepair.duration or 8000,
        label = VRS.L.repair.repairing:format(VRS.GetPartLabel(part)),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()

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
        else
            lib.notify({ title = 'Erro', description = 'Erro no reparo.', type = 'error' })
        end
    end
end

--- Menu de reparo de oficina
---@param vehicle number
---@param shopId string
function VRS.OpenShopRepairMenu(vehicle, shopId)
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
    local options = {}

    for _, part in ipairs(VRS.Parts) do
        local value = status[part] or 0
        local pct = VRS.GetPartPercent(part, value)
        local max = Config.MaxStatus[part] or 100
        local label = VRS.GetPartLabel(part)
        local price = prices[part] or 0

        if pct >= 100 then
            options[#options + 1] = {
                title = label,
                description = VRS.L.repair.already_full:format(label),
                icon = 'fas fa-check-circle',
                iconColor = '#4CAF50',
                disabled = true,
            }
        else
            -- Verificar materiais
            local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, part, false)

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

            options[#options + 1] = {
                title = ('%s (%d%%)'):format(label, pct),
                description = ('Preço: R$ %s | Materiais: %s %s'):format(
                    VRS.FormatMoney(price),
                    matsText,
                    not hasMats and '| SEM MATERIAIS' or ''
                ),
                icon = 'fas fa-tools',
                iconColor = iconColor,
                disabled = not hasMats,
                onSelect = function()
                    VRS.DoShopRepair(vehicle, plate, part, shopId)
                end,
            }
        end
    end

    -- Troca de óleo separada
    if shop.services and shop.services.oil_change then
        local oilPct = VRS.GetPartPercent('oil', status.oil or 0)
        options[#options + 1] = {
            title = 'Troca de Óleo',
            description = ('Nível atual: %d%%'):format(oilPct),
            icon = 'fas fa-oil-can',
            iconColor = oilPct < 30 and '#F44336' or '#4CAF50',
            onSelect = function()
                VRS.DoOilChange(vehicle, plate, shopId)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_shop_repair',
        title = VRS.L.repair.shop_repair,
        description = VRS.L.repair.shop_repair_desc,
        menu = 'vrs_lift_menu',
        options = options,
    })

    lib.showContext('vrs_shop_repair')
end

--- Executar reparo de oficina
---@param vehicle number
---@param plate string
---@param part string
---@param shopId string
function VRS.DoShopRepair(vehicle, plate, part, shopId)
    -- Skill check
    if Config.ShopRepair.skillCheck then
        local success = lib.skillCheck(Config.ShopRepair.skillCheck)
        if not success then
            lib.notify({ title = 'Falha', description = VRS.L.repair.skill_failed, type = 'error' })
            return
        end
    end

    VRS.PlayAnimation('repair')

    local success = lib.progressBar({
        duration = Config.ShopRepair.duration or 12000,
        label = VRS.L.repair.repairing:format(VRS.GetPartLabel(part)),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()

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
    VRS.PlayAnimation('repair')

    local success = lib.progressBar({
        duration = 6000,
        label = 'Trocando óleo...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()

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
        else
            lib.notify({ title = 'Erro', description = 'Erro na troca de óleo.', type = 'error' })
        end
    end
end
