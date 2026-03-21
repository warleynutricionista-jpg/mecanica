local sharedConfig = require 'config.shared'
local clientConfig = require 'config.client'
local access = require 'client.services.access'
local session = require 'client.session'
local feedback = require 'client.services.feedback'
local openCustoms = require 'client.main'

local currentZoneIndex = nil
local textUiVisible = false

local function setTextUiVisible(state)
    if textUiVisible == state then
        return
    end

    textUiVisible = state
    if state then
        lib.showTextUI(locale('textUI.tune'), {
            icon = 'car',
            position = sharedConfig.textUiPosition,
        })
    else
        lib.hideTextUI()
    end
end

local function refreshPrompt()
    local vehicle = cache.vehicle
    local show = currentZoneIndex ~= nil and vehicle ~= nil and not session.isOpen and access.isVehicleAllowed(currentZoneIndex, vehicle)
    setTextUiVisible(show)
end

local function calculateCenter(points)
    local x, y, z = 0.0, 0.0, 0.0
    for i = 1, #points do
        x = x + points[i].x
        y = y + points[i].y
        z = z + points[i].z
    end

    return vec3(x / #points, y / #points, z / #points)
end

CreateThread(function()
    for index = 1, #sharedConfig.zones do
        local zone = sharedConfig.zones[index]
        lib.zones.poly({
            points = zone.points,
            debug = sharedConfig.debug,
            onEnter = function()
                currentZoneIndex = index
                refreshPrompt()
            end,
            onExit = function()
                if currentZoneIndex == index then
                    currentZoneIndex = nil
                end
                setTextUiVisible(false)
            end,
            inside = function()
                refreshPrompt()
                if textUiVisible and IsControlJustPressed(0, clientConfig.controls.openMenu) then
                    openCustoms(index)
                end
            end,
        })

        if not zone.hideBlip then
            local center = calculateCenter(zone.points)
            local blip = AddBlipForCoord(center.x, center.y, center.z)
            SetBlipSprite(blip, 72)
            SetBlipColour(blip, 4)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(zone.label or 'Customs')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

lib.onCache('vehicle', function()
    refreshPrompt()
end)

lib.callback.register('mri_Qbox:customs:client', function()
    if not currentZoneIndex then
        feedback.notify(locale('notifications.error.noZone'), 'error')
        return false
    end

    return openCustoms(currentZoneIndex)
end)
