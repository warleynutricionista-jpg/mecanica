-- ============================================================
-- VRS_MECHANIC - TABLET CLIENT
-- ============================================================

local tabletOpen = false
local currentTabletShop = nil

-- ============================================================
-- ABRIR/FECHAR TABLET
-- ============================================================

--- Abre o tablet
---@param shopId string|nil
function VRS.OpenTablet(shopId)
    if tabletOpen then return end

    shopId = shopId or VRS.GetPlayerShopId()
    if not shopId then
        lib.notify({ title = 'Erro', description = 'Oficina não encontrada.', type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    if not shop or shop.type ~= 'owned' then
        lib.notify({ title = 'Erro', description = 'Tablet disponível apenas para oficinas próprias.', type = 'error' })
        return
    end

    if Config.Tablet.requireJob and not VRS.IsMechanic() then
        lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
        return
    end

    -- Verificar item se configurado
    if Config.Tablet.item then
        local hasItem = lib.callback.await('vrs_mechanic:server:hasItem', false, Config.Tablet.item, 1)
        if not hasItem then
            lib.notify({ title = 'Erro', description = 'Você não tem um tablet.', type = 'error' })
            return
        end
    end

    currentTabletShop = shopId
    tabletOpen = true

    -- Abrir NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        shopId = shopId,
        shopLabel = shop.label,
    })

    -- Carregar dados iniciais
    VRS.LoadTabletData(shopId)
end

--- Fecha o tablet
function VRS.CloseTablet()
    if not tabletOpen then return end

    tabletOpen = false
    currentTabletShop = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Carrega dados para o tablet
---@param shopId string
function VRS.LoadTabletData(shopId)
    -- Carregar tudo em paralelo usando callbacks
    local playerInfo = lib.callback.await('vrs_mechanic:server:getPlayerInfo', false)
    local stats = lib.callback.await('vrs_mechanic:server:getShopStats', false, shopId)
    local orders = lib.callback.await('vrs_mechanic:server:getWorkOrders', false, shopId)
    local employees = lib.callback.await('vrs_mechanic:server:getEmployees', false, shopId)
    local prices = lib.callback.await('vrs_mechanic:server:getShopPrices', false, shopId)
    local isManager = lib.callback.await('vrs_mechanic:server:isManager', false, shopId)

    SendNUIMessage({
        action = 'loadData',
        data = {
            player = playerInfo,
            stats = stats,
            orders = orders,
            employees = employees,
            prices = prices,
            isManager = isManager,
        },
    })
end

-- ============================================================
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('close', function(_, cb)
    VRS.CloseTablet()
    cb('ok')
end)

RegisterNUICallback('getWorkOrders', function(data, cb)
    if not currentTabletShop then cb({}) return end
    local orders = lib.callback.await('vrs_mechanic:server:getWorkOrders', false, currentTabletShop, data.status)
    cb(orders or {})
end)

RegisterNUICallback('updateOrderStatus', function(data, cb)
    local result = lib.callback.await('vrs_mechanic:server:updateWorkOrderStatus', false, data.orderId, data.status)
    cb(result or { success = false })
end)

RegisterNUICallback('getEmployees', function(_, cb)
    if not currentTabletShop then cb({}) return end
    local employees = lib.callback.await('vrs_mechanic:server:getEmployees', false, currentTabletShop)
    cb(employees or {})
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    local result = lib.callback.await('vrs_mechanic:server:hireEmployee', false, currentTabletShop, data.targetId)
    cb(result or { success = false })
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    local result = lib.callback.await('vrs_mechanic:server:fireEmployee', false, currentTabletShop, data.citizenid)
    cb(result or { success = false })
end)

RegisterNUICallback('updatePrice', function(data, cb)
    local result = lib.callback.await('vrs_mechanic:server:updatePrice', false, currentTabletShop, data.service, data.price)
    cb(result or { success = false })
end)

RegisterNUICallback('getPrices', function(_, cb)
    if not currentTabletShop then cb({}) return end
    local prices = lib.callback.await('vrs_mechanic:server:getShopPrices', false, currentTabletShop)
    cb(prices or {})
end)

RegisterNUICallback('getBillingHistory', function(_, cb)
    if not currentTabletShop then cb({}) return end
    local history = lib.callback.await('vrs_mechanic:server:getBillingHistory', false, currentTabletShop)
    cb(history or {})
end)

RegisterNUICallback('sendBill', function(data, cb)
    data.shopId = currentTabletShop
    local result = lib.callback.await('vrs_mechanic:server:sendBill', false, data)
    cb(result or { success = false })
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    local players = lib.callback.await('vrs_mechanic:server:getNearbyPlayers', false)
    cb(players or {})
end)

-- ============================================================
-- COMANDO
-- ============================================================

if Config.Tablet.command then
    RegisterCommand(Config.Tablet.command, function()
        VRS.OpenTablet()
    end, false)
end

-- Fechar com ESC
CreateThread(function()
    while true do
        if tabletOpen then
            if IsControlJustPressed(0, 200) then -- ESC
                VRS.CloseTablet()
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
