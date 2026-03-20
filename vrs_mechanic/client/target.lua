-- ============================================================
-- VRS_MECHANIC - TARGET CLIENT (ox_target)
-- ============================================================

local liftTargets = {}
local panelTargets = {}
local locationTargets = {}
local vehicleTargetsCreated = false

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

    local metrics = VRS.GetLiftMetrics(lift)
    local offset = rotateOffset(metrics.interactionOffset or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0), lift.coords.w or 0.0)
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

local function getLiftVehicle(shopId, liftIndex)
    local state = VRS.GetLiftStateSnapshot and VRS.GetLiftStateSnapshot(shopId, liftIndex) or nil
    local netId = state and state.vehicleNetId or nil
    if not netId then
        return nil
    end

    return VRS.GetEntityFromNetId and VRS.GetEntityFromNetId(netId, true) or nil
end

local function removeLiftTargets()
    for key, zoneId in pairs(liftTargets) do
        exports.ox_target:removeZone(zoneId)
        liftTargets[key] = nil
    end

    for key, zoneId in pairs(panelTargets) do
        exports.ox_target:removeZone(zoneId)
        panelTargets[key] = nil
    end
end

local function createLiftTargets(shopId, shop)
    if not shop.lifts then return end

    for i, lift in ipairs(shop.lifts) do
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
                    canInteract = function()
                        return VRS.ResolveLiftReference(shopId, i) ~= nil and canUseLiftPanel(shopId)
                    end,
                    onSelect = function()
                        VRS.OpenLiftMenu(shopId, i)
                    end,
                },
                {
                    name = liftId .. '_panel',
                    icon = 'fas fa-sliders',
                    label = 'Painel do Elevador',
                    distance = 3.0,
                    canInteract = function()
                        return VRS.ResolveLiftReference(shopId, i) ~= nil and canUseLiftPanel(shopId)
                    end,
                    onSelect = function()
                        VRS.OpenLiftPanel(shopId, i)
                    end,
                },
                {
                    name = liftId .. '_repair',
                    icon = 'fas fa-wrench',
                    label = 'Reparo de Oficina',
                    distance = 3.0,
                    canInteract = function()
                        return canUseLiftPanel(shopId) and getLiftVehicle(shopId, i) ~= nil
                    end,
                    onSelect = function()
                        local vehicle = getLiftVehicle(shopId, i)
                        if vehicle then
                            VRS.OpenShopRepairMenu(vehicle, shopId)
                        end
                    end,
                },
            },
        })

    end
end

function VRS.RebuildLiftTargets()
    removeLiftTargets()

    for shopId, shop in pairs(Config.Shops) do
        createLiftTargets(shopId, shop)
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
    if vehicleTargetsCreated then return end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'vrs_vehicle_diagnose',
            icon = 'fas fa-stethoscope',
            label = 'Verificar veículo',
            distance = 3.0,
            bones = { 'bonnet' },
            canInteract = function(entity)
                local onLift = entity and VRS.IsVehicleOnLift and select(1, VRS.IsVehicleOnLift(entity)) or false
                return not onLift
            end,
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
            canInteract = function(entity)
                local onLift = entity and VRS.IsVehicleOnLift and select(1, VRS.IsVehicleOnLift(entity)) or false
                return not onLift
            end,
            onSelect = function(data)
                local vehicle = data.entity
                if not vehicle or not DoesEntityExist(vehicle) then return end
                VRS.OpenStreetRepairMenu(vehicle)
            end,
        },
    })

    vehicleTargetsCreated = true
end

local function removeVehicleTargets()
    if not vehicleTargetsCreated then return end

    pcall(function()
        exports.ox_target:removeGlobalVehicle({
            'vrs_vehicle_diagnose',
            'vrs_street_repair',
        })
    end)

    vehicleTargetsCreated = false
end

CreateThread(function()
    for shopId, shop in pairs(Config.Shops) do
        createLocationTargets(shopId, shop)
    end

    VRS.RebuildLiftTargets()
    createVehicleTargets()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    removeLiftTargets()
    removeVehicleTargets()

    for _, zoneId in pairs(locationTargets) do
        exports.ox_target:removeZone(zoneId)
    end
end)
