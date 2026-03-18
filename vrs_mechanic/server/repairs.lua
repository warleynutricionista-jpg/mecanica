-- ============================================================
-- VRS_MECHANIC - REPAIRS SERVER
-- ============================================================

--- Verifica e remove materiais para reparo
---@param source number
---@param part string
---@param isStreet boolean
---@return boolean
local function checkAndRemoveMaterials(source, part, isStreet)
    if isStreet then
        -- Reparo de rua: usar kit básico
        for _, req in ipairs(Config.StreetRepairItems) do
            local count = exports.ox_inventory:Search(source, 'count', req.item)
            if count < req.amount then
                return false
            end
        end
        for _, req in ipairs(Config.StreetRepairItems) do
            if req.amount > 0 then
                exports.ox_inventory:RemoveItem(source, req.item, req.amount)
            end
        end
        return true
    else
        -- Reparo de oficina: materiais específicos
        local materials = Config.RepairMaterials[part]
        if not materials then return false end

        -- Verificar todos primeiro
        for _, req in ipairs(materials) do
            if req.amount > 0 then
                local count = exports.ox_inventory:Search(source, 'count', req.item)
                if count < req.amount then
                    return false
                end
            end
        end

        -- Remover todos
        for _, req in ipairs(materials) do
            if req.amount > 0 then
                exports.ox_inventory:RemoveItem(source, req.item, req.amount)
            end
        end
        return true
    end
end

-- ============================================================
-- CALLBACK: REPARO DE OFICINA
-- ============================================================
lib.callback.register('vrs_mechanic:server:repairPart', function(source, data)
    local src = source
    local plate = data.plate
    local part = data.part
    local shopId = data.shopId
    local netId = data.netId

    -- Validações de segurança
    if not plate or not part or not VRS.IsValidPart(part) then
        return { success = false, reason = 'invalid_data' }
    end

    if not VRS.CheckCooldown(src, 'repair') then
        return { success = false, reason = 'cooldown' }
    end

    -- Validar job e duty para oficina owned
    if shopId and Config.Shops[shopId] then
        local shop = Config.Shops[shopId]
        if shop.type == 'owned' then
            if Config.ShopRepair.requireJob and not VRS.HasShopAccess(src, shopId) then
                return { success = false, reason = 'no_access' }
            end
            if Config.ShopRepair.requireDuty and not VRS.IsOnDuty(src) then
                return { success = false, reason = 'not_on_duty' }
            end
        end
    end

    local serviceValid, serviceReason = VRS.ValidateServiceContext(src, 'repair', part, {
        plate = plate,
        netId = netId,
        shopId = shopId,
    })
    if not serviceValid then
        return { success = false, reason = serviceReason or 'invalid_vehicle' }
    end

    -- Verificar e consumir materiais
    if not checkAndRemoveMaterials(src, part, false) then
        return { success = false, reason = 'no_materials' }
    end

    -- Aplicar reparo
    local status = exports[GetCurrentResourceName()]:GetVehicleStatus(plate)
    if not status then
        return { success = false, reason = 'no_vehicle' }
    end

    local max = Config.MaxStatus[part] or 100
    status[part] = max

    exports[GetCurrentResourceName()]:SetVehiclePartStatus(plate, part, max)

    -- Log
    TriggerEvent('vrs_mechanic:server:log', {
        action = 'repair',
        source = src,
        plate = plate,
        part = part,
        shopId = shopId,
        type = 'shop',
    })

    return { success = true, newValue = max }
end)

-- ============================================================
-- CALLBACK: REPARO DE RUA
-- ============================================================
lib.callback.register('vrs_mechanic:server:streetRepair', function(source, data)
    local src = source
    local plate = data.plate
    local part = data.part
    local netId = data.netId

    if not Config.StreetRepair.enabled then
        return { success = false, reason = 'disabled' }
    end

    if not plate or not part then
        return { success = false, reason = 'invalid_data' }
    end

    if not VRS.CheckCooldown(src, 'repair') then
        return { success = false, reason = 'cooldown' }
    end

    -- Verificar se a parte é permitida para reparo de rua
    if not VRS.TableContains(Config.StreetRepair.allowedParts, part) then
        return { success = false, reason = 'not_allowed_street' }
    end

    local serviceValid, serviceReason = VRS.ValidateServiceContext(src, 'repair', part, {
        plate = plate,
        netId = netId,
    })
    if not serviceValid then
        return { success = false, reason = serviceReason or 'invalid_vehicle' }
    end

    -- Verificar e consumir materiais
    if not checkAndRemoveMaterials(src, part, true) then
        return { success = false, reason = 'no_materials' }
    end

    -- Aplicar reparo limitado
    local status = exports[GetCurrentResourceName()]:GetVehicleStatus(plate)
    if not status then
        return { success = false, reason = 'no_vehicle' }
    end

    local max = Config.MaxStatus[part] or 100
    local maxRecovery = max * (Config.StreetRepair.maxRecovery / 100)
    local currentValue = status[part] or 0
    local newValue = math.min(currentValue + maxRecovery, maxRecovery)

    -- Não ultrapassar o máximo de reparo de rua
    newValue = math.min(newValue, maxRecovery)

    exports[GetCurrentResourceName()]:SetVehiclePartStatus(plate, part, newValue)

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'repair',
        source = src,
        plate = plate,
        part = part,
        type = 'street',
    })

    return { success = true, newValue = newValue }
end)

-- ============================================================
-- CALLBACK: TROCA DE ÓLEO
-- ============================================================
lib.callback.register('vrs_mechanic:server:changeOil', function(source, data)
    local src = source
    local plate = data.plate
    local shopId = data.shopId
    local netId = data.netId

    if not plate then
        return { success = false, reason = 'invalid_data' }
    end

    if not VRS.CheckCooldown(src, 'repair') then
        return { success = false, reason = 'cooldown' }
    end

    local serviceValid, serviceReason = VRS.ValidateServiceContext(src, 'repair', 'oil', {
        plate = plate,
        netId = netId,
        shopId = shopId,
    })
    if not serviceValid then
        return { success = false, reason = serviceReason or 'invalid_vehicle' }
    end

    -- Verificar item de óleo
    local oilMaterials = Config.RepairMaterials.oil
    if oilMaterials then
        for _, req in ipairs(oilMaterials) do
            if req.amount > 0 then
                local count = exports.ox_inventory:Search(src, 'count', req.item)
                if count < req.amount then
                    return { success = false, reason = 'no_materials' }
                end
            end
        end
        for _, req in ipairs(oilMaterials) do
            if req.amount > 0 then
                exports.ox_inventory:RemoveItem(src, req.item, req.amount)
            end
        end
    end

    exports[GetCurrentResourceName()]:SetVehiclePartStatus(plate, 'oil', Config.MaxStatus.oil)

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'oil_change',
        source = src,
        plate = plate,
        shopId = shopId,
    })

    return { success = true }
end)

-- ============================================================
-- CALLBACK: VERIFICAR MATERIAIS DISPONÍVEIS
-- ============================================================
lib.callback.register('vrs_mechanic:server:checkMaterials', function(source, part, isStreet)
    local src = source

    if isStreet then
        for _, req in ipairs(Config.StreetRepairItems) do
            local count = exports.ox_inventory:Search(src, 'count', req.item)
            if count < req.amount then return false end
        end
        return true
    end

    local materials = Config.RepairMaterials[part]
    if not materials then return false end

    for _, req in ipairs(materials) do
        if req.amount > 0 then
            local count = exports.ox_inventory:Search(src, 'count', req.item)
            if count < req.amount then return false end
        end
    end
    return true
end)
