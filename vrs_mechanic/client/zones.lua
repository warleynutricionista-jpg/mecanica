-- ============================================================
-- VRS_MECHANIC - ZONES CLIENT
-- ============================================================

local shopZones = {}
local blips = {}

--- Cria blip para oficina
---@param shopId string
---@param shop table
local function createBlip(shopId, shop)
    if not shop.blip or not shop.blip.enabled then return end

    local zone = shop.zones and shop.zones.main
    if not zone then return end

    local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(blip, shop.blip.sprite or 446)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, shop.blip.scale or 0.7)
    SetBlipColour(blip, shop.blip.color or 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(shop.blip.label or shop.label)
    EndTextCommandSetBlipName(blip)

    blips[shopId] = blip
end

--- Cria zonas para oficina
---@param shopId string
---@param shop table
local function createShopZones(shopId, shop)
    if not shop.zones or not shop.zones.main then return end

    local zone = shop.zones.main
    local useRotatedGeometry = VRS.IsExperimentalEnabled('RotatedWorkshopZones') and zone.rotation ~= nil and zone.size ~= nil
    local debugEnabled = VRS.IsDebugEnabled('rotatedZones') and useRotatedGeometry
    shopZones[shopId] = lib.zones.box({
        coords = zone.coords,
        size = zone.size or vec3(20.0, 20.0, 5.0),
        rotation = zone.rotation or 0.0,
        debug = debugEnabled,
        onEnter = function()
            VRS.CurrentShop = shopId
            VRS.InShopZone = true
            if debugEnabled then
                VRS.DebugLog('rotatedZones', ('Entrou na oficina %s usando modo %s.'):format(shopId, useRotatedGeometry and 'rotacionado' or 'legado'))
            end
            if VRS.ScanWorldLifts and Config.Lift.WorldDetection and Config.Lift.WorldDetection.discoverOnZoneEnter then
                VRS.ScanWorldLifts(shopId)
            end
        end,
        onExit = function()
            if VRS.CurrentShop == shopId then
                VRS.CurrentShop = nil
                VRS.InShopZone = false
            end
        end,
    })
end

-- ============================================================
-- INICIALIZAÇÃO
-- ============================================================

CreateThread(function()
    for shopId, shop in pairs(Config.Shops) do
        createBlip(shopId, shop)
        createShopZones(shopId, shop)
    end
end)

-- Limpar ao parar resource
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, zone in pairs(shopZones) do
        if zone.remove then zone:remove() end
    end

    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
end)
