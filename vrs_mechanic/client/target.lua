-- ============================================================
-- VRS_MECHANIC - TARGET CLIENT (ox_target)
-- ============================================================

local liftTargets = {}
local panelTargets = {}
local locationTargets = {}

local function rotateOffset(offset, heading)
    local radians = math.rad(heading or 0.0)
    local cosHeading = math.cos(radians)
    local sinHeading = math.sin(radians)

    return vec3(
        (offset.x * cosHeading) - (offset.y * sinHeading),
        (offset.x * sinHeading) + (offset.y * cosHeading),
        offset.z or 0.0
    )
end

local function getLiftPanelCoords(lift)
    if lift.controlPanel then
        return lift.controlPanel
    end

    local offset = rotateOffset(Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0), lift.coords.w or 0.0)
    return vec4(
        lift.coords.x + offset.x,
        lift.coords.y + offset.y,
        lift.coords.z + offset.z,
        lift.coords.w or 0.0
    )
end

local function canUseLiftPanel(shopId)
    return VRS.CanUseLift(shopId)
end

local function createLiftTargets(shopId, shop)
    if not shop.lifts then return end

    for i, lift in ipairs(shop.lifts) do
        -- Zona do elevador (para menu de serviços)
        local liftId = ('vrs_lift_%s_%d'):format(shopId, i)
        liftTargets[liftId] = exports.ox_target:addBoxZone({
            coords = vec3(lift.coords.x, lift.coords.y, lift.coords.z),
            size = vec3(lift.width or 2.5, lift.length or 5.0, 2.0),
            rotation = lift.coords.w or 0.0,
            debug = false,
            options = {
                {
                    name = liftId .. '_menu',
                    icon = 'fas fa-car-side',
                    label = 'Serviços do elevador',
                    distance = 3.0,
                    onSelect = function()
                        VRS.OpenLiftMenu(shopId, i)
                    end,
                },
            },
        })

        -- Painel de controle físico (abre NUI mini panel)
        local panelCoords = getLiftPanelCoords(lift)
        local panelId = ('vrs_lift_panel_%s_%d'):format(shopId, i)
        panelTargets[panelId] = exports.ox_target:addBoxZone({
            coords = vec3(panelCoords.x, panelCoords.y, panelCoords.z),
            size = Config.Lift.controlPanelSize or vec3(0.6, 0.6, 1.8),
            rotation = panelCoords.w or 0.0,
            debug = false,
            options = {
                {
                    name = panelId .. '_open',
                    icon = 'fas fa-sliders',
                    label = 'Painel do Elevador',
                    distance = Config.Lift.controlPanelDistance or 2.5,
                    groups = shop.job and { [shop.job] = 0 } or nil,
                    canInteract = function()
                        return canUseLiftPanel(shopId)
                    end,
                    onSelect = function()
                        VRS.OpenLiftPanel(shopId, i)
                    end,
                },
            },
        })
    end
end

local function createLocationTargets(shopId, shop)
    if not shop.locations then return end

    if shop.locations.duty then
        local dutyId = ('vrs_duty_%s'):format(shopId)
        locationTargets[dutyId] = exports.ox_target:addBoxZone({
            coords = shop.locations.duty,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0.0,
            debug = false,
            options = {
                {
                    name = dutyId,
                    icon = 'fas fa-clipboard-check',
                    label = VRS.L.duty.toggle,
                    distance = 2.0,
                    groups = shop.job and { [shop.job] = 0 } or nil,
                    onSelect = function()
                        VRS.ToggleDuty()
                    end,
                },
            },
        })
    end

    if shop.locations.stash and shop.stash then
        local stashId = ('vrs_stash_%s'):format(shopId)
        locationTargets[stashId] = exports.ox_target:addBoxZone({
            coords = shop.locations.stash,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0.0,
            debug = false,
            options = {
                {
                    name = stashId,
                    icon = 'fas fa-box-open',
                    label = VRS.L.stash.title:format(shop.label),
                    distance = 2.0,
                    groups = shop.job and { [shop.job] = 0 } or nil,
                    onSelect = function()
                        VRS.OpenStash(shopId)
                    end,
                },
            },
        })
    end

    if shop.locations.shop then
        local shopPointId = ('vrs_shop_%s'):format(shopId)
        locationTargets[shopPointId] = exports.ox_target:addBoxZone({
            coords = shop.locations.shop,
            size = vec3(1.8, 1.8, 2.0),
            rotation = 0.0,
            debug = false,
            options = {
                {
                    name = shopPointId,
                    icon = 'fas fa-store',
                    label = 'Abrir loja de peças',
                    distance = 2.0,
                    onSelect = function()
                        VRS.OpenPartsShop(shopId)
                    end,
                },
            },
        })
    end

    if shop.locations.tablet then
        local tabletId = ('vrs_tablet_%s'):format(shopId)
        locationTargets[tabletId] = exports.ox_target:addBoxZone({
            coords = shop.locations.tablet,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0.0,
            debug = false,
            options = {
                {
                    name = tabletId,
                    icon = 'fas fa-tablet-alt',
                    label = 'Abrir tablet da oficina',
                    distance = 2.0,
                    groups = shop.job and { [shop.job] = 0 } or nil,
                    onSelect = function()
                        VRS.OpenTablet(shopId)
                    end,
                },
            },
        })
    end
end

local function createVehicleTargets()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vrs_vehicle_diagnose',
            icon = 'fas fa-stethoscope',
            label = 'Verificar veículo',
            distance = 3.0,
            bones = { 'bonnet' },
            onSelect = function(data)
                local vehicle = data.entity
                if not vehicle or not DoesEntityExist(vehicle) then return end
                VRS.QuickDiagnostic(vehicle)
            end,
        },
        {
            name = 'vrs_street_repair',
            icon = 'fas fa-wrench',
            label = VRS.L.repair.street_repair,
            distance = 3.0,
            bones = { 'bonnet' },
            onSelect = function(data)
                local vehicle = data.entity
                if not vehicle or not DoesEntityExist(vehicle) then return end
                VRS.OpenStreetRepairMenu(vehicle)
            end,
        },
    })
end

CreateThread(function()
    for shopId, shop in pairs(Config.Shops) do
        createLiftTargets(shopId, shop)
        createLocationTargets(shopId, shop)
    end

    createVehicleTargets()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for id in pairs(liftTargets) do
        exports.ox_target:removeZone(id)
    end
    for id in pairs(panelTargets) do
        exports.ox_target:removeZone(id)
    end
    for id in pairs(locationTargets) do
        exports.ox_target:removeZone(id)
    end
end)
