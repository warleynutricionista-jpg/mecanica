-- ============================================================
-- VRS_MECHANIC - TABLET CLIENT
-- ============================================================

local tabletOpen = false
local currentTabletShop = nil

local function translateTabletReason(reason)
    local messages = {
        not_mechanic = VRS.L.repair.not_mechanic,
        not_on_duty = VRS.L.repair.not_on_duty,
        no_permission = VRS.L.notify.no_permission,
        no_shop = 'Nenhuma oficina configurada para o seu cargo.',
        invalid_shop = 'A oficina selecionada não é válida.',
        missing_tablet = 'Você precisa ter um tablet mecânico no inventário.',
    }

    return messages[reason] or 'Não foi possível abrir o tablet agora.'
end

local function setTabletFocus(state)
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

local function sendTabletMessage(payload)
    payload.resource = GetCurrentResourceName()
    SendNUIMessage(payload)
end

function VRS.IsTabletOpen()
    return tabletOpen
end

function VRS.OpenTablet(shopId)
    if tabletOpen then
        sendTabletMessage({ action = 'focusTab', tab = 'dashboard' })
        return
    end

    shopId = shopId or VRS.CurrentShop or VRS.GetPlayerShopId()
    if not shopId then
        lib.notify({ title = 'Tablet', description = 'Nenhuma oficina encontrada para abrir o tablet.', type = 'error' })
        return
    end

    local response = lib.callback.await('vrs_mechanic:server:getTabletBootstrap', false, shopId)
    if not response or not response.success then
        lib.notify({
            title = 'Tablet',
            description = translateTabletReason(response and response.reason or 'unknown'),
            type = 'error',
        })
        return
    end

    local shop = Config.Shops[shopId]
    currentTabletShop = shopId
    tabletOpen = true

    setTabletFocus(true)
    sendTabletMessage({
        action = 'open',
        shopId = shopId,
        shopLabel = shop and shop.label or 'Oficina',
        data = response.data,
    })
end

function VRS.CloseTablet()
    if not tabletOpen then return end

    tabletOpen = false
    currentTabletShop = nil
    setTabletFocus(false)
    sendTabletMessage({ action = 'close' })
end

function VRS.RefreshTabletData()
    if not tabletOpen or not currentTabletShop then return end

    local response = lib.callback.await('vrs_mechanic:server:getTabletBootstrap', false, currentTabletShop)
    if response and response.success then
        sendTabletMessage({ action = 'hydrate', data = response.data })
    end
end

RegisterNUICallback('close', function(_, cb)
    VRS.CloseTablet()
    cb({ ok = true })
end)

RegisterNUICallback('refreshTablet', function(_, cb)
    VRS.RefreshTabletData()
    cb({ ok = true })
end)

RegisterNUICallback('updateOrderStatus', function(data, cb)
    if not currentTabletShop then
        cb({ success = false, reason = 'no_shop' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:updateWorkOrderStatus', false, data.orderId, data.status)
    if result and result.success then
        VRS.RefreshTabletData()
    end
    cb(result or { success = false })
end)

RegisterNUICallback('updatePrice', function(data, cb)
    if not currentTabletShop then
        cb({ success = false, reason = 'no_shop' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:updatePrice', false, currentTabletShop, data.service, data.price)
    if result and result.success then
        VRS.RefreshTabletData()
    end
    cb(result or { success = false })
end)


RegisterNUICallback('hireEmployee', function(data, cb)
    if not currentTabletShop then
        cb({ success = false, reason = 'no_shop' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:hireEmployee', false, currentTabletShop, data.targetId)
    if result and result.success then
        VRS.RefreshTabletData()
    end
    cb(result or { success = false })
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    if not currentTabletShop then
        cb({ success = false, reason = 'no_shop' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:fireEmployee', false, currentTabletShop, data.citizenid)
    if result and result.success then
        VRS.RefreshTabletData()
    end
    cb(result or { success = false })
end)

RegisterNUICallback('sendBill', function(data, cb)
    if not currentTabletShop then
        cb({ success = false, reason = 'no_shop' })
        return
    end

    data.shopId = currentTabletShop
    local result = lib.callback.await('vrs_mechanic:server:sendBill', false, data)
    if result and result.success then
        VRS.RefreshTabletData()
    end
    cb(result or { success = false })
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    local players = lib.callback.await('vrs_mechanic:server:getNearbyPlayers', false)
    cb(players or {})
end)

RegisterNUICallback('openPartsShop', function(data, cb)
    local shopId = data and data.shopId or currentTabletShop
    VRS.CloseTablet()
    Wait(100)
    VRS.OpenPartsShop(shopId, data and data.category)
    cb({ ok = true })
end)

if Config.Tablet.command then
    RegisterCommand(Config.Tablet.command, function()
        VRS.OpenTablet()
    end, false)
end

CreateThread(function()
    while true do
        if tabletOpen then
            if IsControlJustPressed(0, 200) then
                VRS.CloseTablet()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
