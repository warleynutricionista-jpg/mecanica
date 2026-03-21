Paintjob = Paintjob or {}

local Utils = Paintjob.Utils
local Effects = Paintjob.Effects
local Paint = Paintjob.Paint
local UI = Paintjob.UI
local State = Paintjob.State

local currentBooth = nil
local targetZones = {}
local blips = {}

local function drawControlMarker(booth)
    local marker = Config.UI.Marker
    local coords = Utils.toVec3(booth.control)
    DrawMarker(
        marker.type,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        marker.scale.x, marker.scale.y, marker.scale.z,
        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
        false, false, 2, false, nil, nil, false
    )
end

local function openBoothFlow(boothId)
    if State.busyBooths[boothId] then
        return Utils.notify({ type = 'error', description = 'Esta cabine já está em uso.' })
    end

    local session = Paint.beginSession(boothId)
    if not session then return end

    UI.openMainMenu()
end

local function createTargetZones()
    if not Config.UseTarget or GetResourceState('ox_target') ~= 'started' then return end

    for boothId, booth in ipairs(Config.Locations or {}) do
        local coords = Utils.toVec3(booth.control)
        targetZones[#targetZones + 1] = exports.ox_target:addSphereZone({
            coords = coords,
            radius = Utils.getControlRadius(booth),
            options = {
                {
                    name = ('mri_qpaintjob:%s'):format(boothId),
                    icon = 'fa-solid fa-spray-can-sparkles',
                    label = ('Abrir %s'):format(booth.name or 'cabine de pintura'),
                    canInteract = function()
                        return not State.busyBooths[boothId]
                    end,
                    onSelect = function()
                        openBoothFlow(boothId)
                    end,
                },
            },
        })
    end
end

local function removeTargetZones()
    if GetResourceState('ox_target') ~= 'started' then return end
    for _, zoneId in ipairs(targetZones) do
        exports.ox_target:removeZone(zoneId)
    end
    targetZones = {}
end

local function createBlips()
    for boothId, booth in ipairs(Config.Locations or {}) do
        if booth.blip and booth.blip.enabled ~= false then
            local coords = Utils.toVec3(booth.control)
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, booth.blip.sprite or 72)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, booth.blip.scale or 0.7)
            SetBlipColour(blip, booth.blip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(booth.blip.label or booth.name or ('Cabine de Pintura %s'):format(boothId))
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end

local function removeBlips()
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blips = {}
end

CreateThread(function()
    local busySnapshot = lib.callback.await('mri_Qpaintjob:server:getBusyBooths', false)
    if type(busySnapshot) == 'table' then
        State.busyBooths = busySnapshot
    end

    Effects.spawnSprayProps()
    createTargetZones()
    createBlips()

    if Config.UseTarget then return end

    while true do
        local pedCoords = GetEntityCoords(cache.ped)
        local nearestBooth, nearestDistance = nil, math.huge

        for boothId, booth in ipairs(Config.Locations or {}) do
            local distance = Utils.distance(pedCoords, booth.control)
            if distance < nearestDistance and distance <= 20.0 then
                nearestDistance = distance
                nearestBooth = boothId
            end
        end

        currentBooth = nearestBooth
        Wait(currentBooth and 250 or 1000)
    end
end)

CreateThread(function()
    if Config.UseTarget then return end

    local textVisible = false

    while true do
        if not currentBooth then
            if textVisible then
                lib.hideTextUI()
                textVisible = false
            end
            Wait(500)
        else
            local booth = Config.Locations[currentBooth]
            local distance = Utils.distance(GetEntityCoords(cache.ped), booth.control)
            if distance <= 20.0 then
                drawControlMarker(booth)
            end

            if distance <= Utils.getControlRadius(booth) + 0.25 then
                local helpText = State.busyBooths[currentBooth] and Config.UI.BusyHelp or ('%s • %s'):format(booth.name or 'Cabine de Pintura', Config.UI.ControlHelp)
                if not textVisible then
                    lib.showTextUI(helpText)
                    textVisible = true
                else
                    lib.showTextUI(helpText)
                end

                if not State.busyBooths[currentBooth] and IsControlJustPressed(0, 38) then
                    lib.hideTextUI()
                    textVisible = false
                    openBoothFlow(currentBooth)
                end
            elseif textVisible then
                lib.hideTextUI()
                textVisible = false
            end

            Wait(0)
        end
    end
end)

RegisterNetEvent('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeTargetZones()
    removeBlips()
end)
