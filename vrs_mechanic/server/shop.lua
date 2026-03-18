-- ============================================================
-- VRS_MECHANIC - PARTS SHOP SERVER
-- ============================================================

local function getCurrencyLabel(currency)
    currency = currency == 'money' and 'cash' or currency
    return currency == 'bank' and 'banco' or 'carteira'
end

local function normalizeCurrency(currency)
    if currency == 'money' then
        return 'cash'
    end

    return currency
end

local function getPlayerMoney(player, currency)
    currency = normalizeCurrency(currency)
    local money = player.Functions.GetMoney and player.Functions.GetMoney(currency) or nil

    if type(money) == 'number' then
        return money
    end

    return (player.PlayerData.money and player.PlayerData.money[currency]) or 0
end

local function removePlayerMoney(player, currency, amount, reason)
    currency = normalizeCurrency(currency)
    return player.Functions.RemoveMoney(currency, amount, reason)
end

local function addPlayerMoney(player, currency, amount, reason)
    currency = normalizeCurrency(currency)
    return player.Functions.AddMoney(currency, amount, reason)
end

local function addItemToInventory(source, itemName, amount)
    return exports.ox_inventory:AddItem(source, itemName, amount)
end

local function getShopCatalogForPlayer(source, shopId)
    local shop = Config.Shops[shopId]
    if not shop or not Config.PartsShop.enabled then
        return nil, 'shop_not_found'
    end

    local shopConfig = shop.partsShop or {}
    local isPublic = shopConfig.public == true or (shop.type == 'self-service' and Config.PartsShop.defaultPublic)
    local requiresJob = shopConfig.jobOnly ~= false and not isPublic

    if requiresJob and not VRS.HasShopAccess(source, shopId) then
        return nil, 'no_access'
    end

    if requiresJob and Config.PartsShop.requireDutyForWorkshopOnly and not VRS.IsOnDuty(source) then
        return nil, 'not_on_duty'
    end

    local categories = {}
    local items = {}
    local countsByCategory = {}

    for categoryId, category in pairs(Config.PartsShop.categories) do
        if category.enabled ~= false then
            categories[#categories + 1] = {
                id = categoryId,
                label = category.label,
                description = category.description,
                icon = category.icon,
            }
            countsByCategory[categoryId] = 0
        end
    end

    table.sort(categories, function(a, b)
        return a.label < b.label
    end)

    for itemName, item in pairs(Config.PartsShop.items) do
        local category = Config.PartsShop.categories[item.category]
        local featureAllowed = item.requiresFeature ~= 'nitrous' or Config.Upgrades.enabled
        local allowedForContext = not item.workshopOnly or not isPublic

        if category and category.enabled ~= false and featureAllowed and allowedForContext then
            countsByCategory[item.category] = (countsByCategory[item.category] or 0) + 1
            items[#items + 1] = {
                name = itemName,
                label = item.label,
                category = item.category,
                description = item.description,
                price = item.price,
                stock = item.stock or 0,
                icon = item.icon or category.icon,
                workshopOnly = item.workshopOnly == true,
            }
        end
    end

    table.sort(items, function(a, b)
        if a.category == b.category then
            return a.label < b.label
        end
        return a.category < b.category
    end)

    for _, category in ipairs(categories) do
        category.count = countsByCategory[category.id] or 0
    end

    return {
        shopId = shopId,
        shopLabel = shop.label,
        currency = Config.PartsShop.currency,
        currencyLabel = getCurrencyLabel(Config.PartsShop.currency),
        public = isPublic,
        categories = categories,
        items = items,
        maxPurchaseQuantity = Config.PartsShop.maxPurchaseQuantity,
    }
end

lib.callback.register('vrs_mechanic:server:getPartsCatalog', function(source, shopId)
    local catalog, reason = getShopCatalogForPlayer(source, shopId)
    if not catalog then
        return { success = false, reason = reason }
    end

    return { success = true, data = catalog }
end)

lib.callback.register('vrs_mechanic:server:purchasePartsItem', function(source, shopId, itemName, quantity)
    local src = source
    quantity = math.floor(tonumber(quantity) or 0)

    if not VRS.CheckCooldown(src, 'partsShop') then
        return { success = false, reason = 'cooldown' }
    end

    local catalog, reason = getShopCatalogForPlayer(src, shopId)
    if not catalog then
        return { success = false, reason = reason }
    end

    if quantity < 1 or quantity > Config.PartsShop.maxPurchaseQuantity then
        return { success = false, reason = 'invalid_quantity' }
    end

    local item = Config.PartsShop.items[itemName]
    if not item then
        return { success = false, reason = 'item_not_found' }
    end

    local category = Config.PartsShop.categories[item.category]
    if not category or category.enabled == false then
        return { success = false, reason = 'item_not_available' }
    end

    if item.requiresFeature == 'nitrous' and not Config.Upgrades.enabled then
        return { success = false, reason = 'item_not_available' }
    end

    if item.workshopOnly and catalog.public then
        return { success = false, reason = 'item_not_available' }
    end

    local stock = item.stock or 0
    if stock > 0 and quantity > stock then
        return { success = false, reason = 'insufficient_stock' }
    end

    local totalPrice = (item.price or 0) * quantity
    if totalPrice <= 0 then
        return { success = false, reason = 'invalid_price' }
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        return { success = false, reason = 'player_not_found' }
    end

    local currency = normalizeCurrency(Config.PartsShop.currency or 'cash')
    if getPlayerMoney(player, currency) < totalPrice then
        return { success = false, reason = 'insufficient_funds' }
    end

    local canCarry = exports.ox_inventory:CanCarryItem(src, itemName, quantity)
    if not canCarry then
        return { success = false, reason = 'inventory_full' }
    end

    local removed = removePlayerMoney(player, currency, totalPrice, 'vrs_mechanic_parts_shop')
    if removed == false then
        return { success = false, reason = 'payment_failed' }
    end

    local added = addItemToInventory(src, itemName, quantity)
    if not added then
        addPlayerMoney(player, currency, totalPrice, 'vrs_mechanic_parts_refund')
        return { success = false, reason = 'inventory_add_failed' }
    end

    TriggerEvent('vrs_mechanic:server:log', {
        action = 'parts_purchase',
        source = src,
        shopId = shopId,
        item = itemName,
        quantity = quantity,
        amount = totalPrice,
    })

    return {
        success = true,
        itemLabel = item.label,
        quantity = quantity,
        totalPrice = totalPrice,
        currency = currency,
    }
end)


lib.callback.register('vrs_mechanic:server:getTabletBootstrap', function(source, shopId)
    local src = source
    local allowed, reason = VRS.ValidatePanelAccess(src, 'tablet', shopId)
    if not allowed then
        return { success = false, reason = reason }
    end

    local player = exports.qbx_core:GetPlayer(src)
    local shop = Config.Shops[shopId]
    if not player or not shop then
        return { success = false, reason = 'invalid_shop' }
    end

    if Config.Tablet.item then
        local count = exports.ox_inventory:Search(src, 'count', Config.Tablet.item)
        if count < 1 then
            return { success = false, reason = 'missing_tablet' }
        end
    end

    local catalog = nil
    local shopConfig = shop.partsShop or {}
    if shopConfig.allowTabletAccess ~= false then
        local catalogData = getShopCatalogForPlayer(src, shopId)
        if type(catalogData) == 'table' then
            catalog = catalogData
        end
    end

    local orders = MySQL.query.await(
        [[SELECT * FROM vrs_mechanic_work_orders
          WHERE shop_id = ?
          ORDER BY created_at DESC LIMIT 50]],
        { shopId }
    ) or {}

    for _, order in ipairs(orders) do
        order.problems = order.problems and json.decode(order.problems) or {}
        order.materials = order.materials and json.decode(order.materials) or {}
    end

    local overrides = MySQL.query.await(
        'SELECT service, price FROM vrs_mechanic_price_overrides WHERE shop_id = ?',
        { shopId }
    ) or {}

    local prices = {}
    for service, basePrice in pairs(shop.basePrices or {}) do
        prices[service] = basePrice
    end
    for _, row in ipairs(overrides) do
        prices[row.service] = row.price
    end

    local employeesResult = MySQL.query.await(
        [[SELECT e.citizenid, e.grade, e.hired_at, p.charinfo
          FROM vrs_mechanic_employees e
          LEFT JOIN players p ON p.citizenid = e.citizenid
          WHERE e.shop_id = ?
          ORDER BY e.grade DESC]],
        { shopId }
    ) or {}

    local employees = {}
    for _, row in ipairs(employeesResult) do
        local charinfo = row.charinfo and json.decode(row.charinfo) or {}
        local isOnline = false
        for _, playerId in ipairs(GetPlayers()) do
            local onlinePlayer = exports.qbx_core:GetPlayer(tonumber(playerId))
            if onlinePlayer and onlinePlayer.PlayerData.citizenid == row.citizenid then
                isOnline = true
                break
            end
        end

        employees[#employees + 1] = {
            citizenid = row.citizenid,
            name = ((charinfo.firstname or 'Desconhecido') .. ' ' .. (charinfo.lastname or '')):gsub('%s+$', ''),
            grade = row.grade,
            hiredAt = row.hired_at,
            online = isOnline,
        }
    end

    local totalOrders = MySQL.scalar.await('SELECT COUNT(*) FROM vrs_mechanic_work_orders WHERE shop_id = ?', { shopId }) or 0
    local completedOrders = MySQL.scalar.await(
        'SELECT COUNT(*) FROM vrs_mechanic_work_orders WHERE shop_id = ? AND status IN (?, ?)',
        { shopId, VRS.OrderStatus.DONE, VRS.OrderStatus.DELIVERED }
    ) or 0
    local revenue = MySQL.scalar.await('SELECT COALESCE(SUM(amount), 0) FROM vrs_mechanic_service_logs WHERE shop_id = ?', { shopId }) or 0
    local employeeCount = MySQL.scalar.await('SELECT COUNT(*) FROM vrs_mechanic_employees WHERE shop_id = ?', { shopId }) or 0
    local billingHistory = MySQL.query.await(
        [[SELECT * FROM vrs_mechanic_service_logs
          WHERE shop_id = ?
          ORDER BY created_at DESC LIMIT 50]],
        { shopId }
    ) or {}

    return {
        success = true,
        data = {
            player = {
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                citizenid = player.PlayerData.citizenid,
                job = player.PlayerData.job.name,
                grade = player.PlayerData.job.grade.level,
                gradeName = player.PlayerData.job.grade.name,
                onduty = player.PlayerData.job.onduty,
            },
            stats = {
                totalOrders = totalOrders,
                completedOrders = completedOrders,
                revenue = revenue,
                employeeCount = employeeCount,
            },
            orders = orders,
            employees = employees,
            prices = prices,
            billingHistory = billingHistory,
            isManager = VRS.IsManager(src, shopId),
            canAccessShop = catalog ~= nil,
            shopCatalog = catalog,
            permissionLevel = VRS.GetPermissionLevel(src),
        },
    }
end)
