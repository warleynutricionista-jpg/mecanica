local ClientState = {
    menuBusy = false,
    isActionBusy = false,
    zones = {},
    targetZoneIds = {},
    textShown = false,
    useTarget = false,
    menuCooldownUntil = 0,
    playerDead = false
}

local function notify(nType, message)
    lib.notify({ type = nType, description = message })
end

local function now()
    return GetGameTimer()
end

local function inMenuCooldown()
    return now() < ClientState.menuCooldownUntil
end

local function setMenuCooldown(seconds)
    ClientState.menuCooldownUntil = now() + (seconds * 1000)
end

local function hasTarget()
    if not Config.UseOxTarget then return false end
    return GetResourceState('ox_target') == 'started'
end

local function getClosestVehicleWithinDistance(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, maxDistance, false)
    if vehicle == 0 then return nil end
    if #(coords - GetEntityCoords(vehicle)) > maxDistance then return nil end
    return vehicle
end

local function clearTextUi()
    if ClientState.textShown then
        lib.hideTextUI()
        ClientState.textShown = false
    end
end

local function safeState()
    local ok, hasAccess, state = pcall(lib.callback.await, 'bakitelli_mechanic:server:getState', false)
    if not ok then
        notify('error', L('state_unavailable'))
        return nil
    end

    if not hasAccess or type(state) ~= 'table' then
        notify('error', L('no_permission'))
        return nil
    end

    return state
end

local function openServiceMenu()
    if ClientState.isActionBusy then
        notify('error', L('busy_player'))
        return
    end

    local options = {}
    for serviceType, serviceData in pairs(Config.Services) do
        options[#options + 1] = {
            title = serviceData.label,
            icon = serviceData.icon,
            onSelect = function()
                if ClientState.playerDead then
                    notify('error', L('service_failed'))
                    return
                end

                local vehicle = getClosestVehicleWithinDistance(Config.MaxServiceDistance)
                if not vehicle then
                    notify('error', L('no_vehicle'))
                    return
                end

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local canService, reason = lib.callback.await('bakitelli_mechanic:server:canService', false, netId, serviceType)
                if not canService then
                    notify('error', reason or L('service_failed'))
                    return
                end

                ClientState.isActionBusy = true
                local completed = lib.progressCircle({
                    duration = serviceData.duration,
                    position = 'bottom',
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    label = serviceData.label
                })

                if not completed then
                    ClientState.isActionBusy = false
                    notify('error', L('action_canceled'))
                    return
                end

                local success, message = lib.callback.await('bakitelli_mechanic:server:performService', false, netId, serviceType)
                ClientState.isActionBusy = false

                if not success then
                    notify('error', message or L('service_failed'))
                    return
                end

                notify('success', message)
            end
        }
    end

    lib.registerContext({
        id = 'bakitelli_mechanic_services',
        title = L('service_menu'),
        options = options
    })

    lib.showContext('bakitelli_mechanic_services')
end

local function openVehicleMenu(state, stationId)
    local options = {}

    for model, label in pairs(Config.ServiceVehicles) do
        options[#options + 1] = {
            title = label,
            icon = 'truck',
            disabled = state.hasVehicleOut,
            onSelect = function()
                local ok, resp = lib.callback.await('bakitelli_mechanic:server:spawnServiceVehicle', false, stationId, model)
                if not ok then
                    notify('error', resp or L('service_failed'))
                    return
                end

                notify('success', L('service_vehicle_spawned'))
            end
        }
    end

    options[#options + 1] = {
        title = L('return_vehicle'),
        icon = 'warehouse',
        disabled = not state.hasVehicleOut,
        onSelect = function()
            local vehicle = cache.vehicle
            local netId = vehicle and NetworkGetNetworkIdFromEntity(vehicle) or nil
            local ok, message = lib.callback.await('bakitelli_mechanic:server:returnServiceVehicle', false, netId)
            if not ok then
                notify('error', message or L('service_failed'))
                return
            end

            notify('success', message)
        end
    }

    lib.registerContext({
        id = 'bakitelli_mechanic_vehicles',
        title = L('vehicle_menu'),
        options = options
    })

    lib.showContext('bakitelli_mechanic_vehicles')
end

local function openMainMenu(stationId)
    if ClientState.menuBusy or inMenuCooldown() then
        return
    end

    ClientState.menuBusy = true
    setMenuCooldown(Config.Cooldowns.menu)

    local state = safeState()
    if not state then
        ClientState.menuBusy = false
        return
    end

    local options = {
        {
            title = L('toggle_duty'),
            description = state.onDuty and 'ON' or 'OFF',
            icon = 'user-gear',
            onSelect = function()
                TriggerServerEvent('bakitelli_mechanic:server:toggleDuty')
            end
        },
        {
            title = L('service_menu'),
            description = L('menu_desc'),
            icon = 'screwdriver-wrench',
            disabled = state.requireDuty and not state.onDuty,
            onSelect = openServiceMenu
        },
        {
            title = L('vehicle_menu'),
            icon = 'car-side',
            disabled = state.requireDuty and not state.onDuty,
            onSelect = function()
                openVehicleMenu(state, stationId)
            end
        }
    }

    if state.isBoss then
        options[#options + 1] = {
            title = L('boss_hint'),
            icon = 'briefcase',
            readOnly = true,
            description = L('boss_hint_desc')
        }
    end

    lib.registerContext({
        id = 'bakitelli_mechanic_main',
        title = L('menu_title'),
        options = options
    })

    lib.showContext('bakitelli_mechanic_main')
    ClientState.menuBusy = false
end

local function addFallbackZone(point, action)
    local zone = lib.zones.sphere({
        coords = point,
        radius = 1.5,
        inside = function(self)
            if self.currentDistance <= 1.2 then
                if not ClientState.textShown then
                    lib.showTextUI(L('use_station'))
                    ClientState.textShown = true
                end

                if IsControlJustReleased(0, 38) then
                    action()
                end
            end
        end,
        onExit = clearTextUi
    })

    ClientState.zones[#ClientState.zones + 1] = zone
end

local function registerTargetInteractions()
    for i = 1, #Config.Stations do
        local station = Config.Stations[i]

        local id1 = exports.ox_target:addSphereZone({
            coords = station.service,
            radius = 1.5,
            options = {
                {
                    name = ('baki_main_%s'):format(i),
                    label = L('open_mechanic_menu'),
                    icon = 'fa-solid fa-wrench',
                    onSelect = function()
                        openMainMenu(i)
                    end
                }
            }
        })

        local id2 = exports.ox_target:addSphereZone({
            coords = station.stash,
            radius = 1.5,
            options = {
                {
                    name = ('baki_stash_%s'):format(i),
                    label = L('open_stash'),
                    icon = 'fa-solid fa-box-open',
                    onSelect = function()
                        exports.ox_inventory:openInventory('stash', { id = Config.Stash.id })
                    end
                }
            }
        })

        ClientState.targetZoneIds[#ClientState.targetZoneIds + 1] = id1
        ClientState.targetZoneIds[#ClientState.targetZoneIds + 1] = id2
    end
end

local function registerFallbackInteractions()
    if not Config.FallbackUseZones then
        notify('error', L('target_missing'))
        return
    end

    for i = 1, #Config.Stations do
        local station = Config.Stations[i]
        addFallbackZone(station.service, function()
            openMainMenu(i)
        end)
        addFallbackZone(station.stash, function()
            exports.ox_inventory:openInventory('stash', { id = Config.Stash.id })
        end)
    end

    notify('inform', L('fallback_active'))
end

local function registerBlips()
    if not Config.UseRadialBlips then return end

    for i = 1, #Config.Stations do
        local st = Config.Stations[i]
        local blip = AddBlipForCoord(st.blip.x, st.blip.y, st.blip.z)
        SetBlipSprite(blip, 402)
        SetBlipScale(blip, 0.7)
        SetBlipDisplay(blip, 4)
        SetBlipColour(blip, 5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(st.label)
        EndTextCommandSetBlipName(blip)
    end
end

local function init()
    registerBlips()
    ClientState.useTarget = hasTarget()

    if ClientState.useTarget then
        registerTargetInteractions()
    else
        registerFallbackInteractions()
    end
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    init()
end)

RegisterNetEvent('bakitelli_mechanic:client:applyService', function(netId, serviceType)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('error', L('invalid_vehicle'))
        return
    end

    if serviceType == 'repair' then
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        SetVehicleFixed(vehicle)
    elseif serviceType == 'clean' then
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
    end
end)

AddEventHandler('baseevents:onPlayerDied', function()
    ClientState.playerDead = true
    ClientState.isActionBusy = false
end)

AddEventHandler('baseevents:onPlayerSpawned', function()
    ClientState.playerDead = false
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearTextUi()

    if ClientState.useTarget then
        for _, id in ipairs(ClientState.targetZoneIds) do
            exports.ox_target:removeZone(id)
        end
    else
        for _, zone in ipairs(ClientState.zones) do
            zone:remove()
        end
    end
end)
