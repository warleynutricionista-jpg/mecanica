local zoneId
local allowAccess = false
local textUiVisible = false

local sharedConfig = require 'config.shared'
local constants = require 'client.constants'
local session = require 'client.session'
local access = require 'client.services.access'
local openCustoms = require 'client.main'

local function setTextUiVisible(visible)
    if visible == textUiVisible then
        return
    end

    textUiVisible = visible

    if visible then
        lib.showTextUI(locale('textUI.tune'), {
            icon = 'fa-solid fa-car',
            position = 'right-center',
        })
        return
    end

    lib.hideTextUI()
end

local function refreshAccess(vehicle)
    allowAccess = access.isVehicleAllowed(zoneId, vehicle)
    setTextUiVisible(vehicle and allowAccess and not session.isOpen)
end

---@param vertices vector3[]
---@return vector3
local function calculatePolyzoneCenter(vertices)
    local xSum = 0
    local ySum = 0
    local zSum = 0

    for i = 1, #vertices do
        xSum += vertices[i].x
        ySum += vertices[i].y
        zSum += vertices[i].z
    end

    return vec3(xSum / #vertices, ySum / #vertices, zSum / #vertices)
end

local function tryOpenCustoms()
    if session.isOpen or session.isClosing then
        exports.qbx_core:Notify(locale('notifications.error.busy'), 'error')
        return false
    end

    if not cache.vehicle or not allowAccess then
        return false
    end

    if GetPedInVehicleSeat(cache.vehicle, -1) ~= cache.ped then
        exports.qbx_core:Notify(locale('notifications.error.driverSeat'), 'error')
        return false
    end

    SetEntityVelocity(cache.vehicle, 0.0, 0.0, 0.0)
    setTextUiVisible(false)
    return openCustoms()
end

CreateThread(function()
    for _, zone in ipairs(sharedConfig.zones) do
        lib.zones.poly({
            debug = sharedConfig.debug,
            points = zone.points,
            onEnter = function(state)
                zoneId = state.id
                refreshAccess(cache.vehicle)
            end,
            onExit = function()
                zoneId = nil
                allowAccess = false
                setTextUiVisible(false)
            end,
            inside = function()
                if not cache.vehicle or not allowAccess or session.isOpen then
                    if textUiVisible and session.isOpen then
                        setTextUiVisible(false)
                    end
                    return
                end

                setTextUiVisible(true)

                if IsControlJustPressed(0, constants.controls.openMenu) then
                    tryOpenCustoms()
                end
            end,
        })

        if not zone.hideBlip then
            local center = calculatePolyzoneCenter(zone.points)
            local blip = AddBlipForCoord(center.x, center.y, center.z)
            SetBlipSprite(blip, zone.blip.sprite or 72)
            SetBlipColour(blip, zone.blip.color or 4)
            SetBlipScale(blip, zone.blip.scale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(zone.blip.label or 'Customs')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

lib.callback.register('qbx_customs:client:zone', function()
    return zoneId
end)

lib.onCache('vehicle', function(vehicle)
    if not zoneId then return end
    refreshAccess(vehicle)
end)

lib.callback.register('mri_Qbox:customs:client', function()
    setTextUiVisible(false)
    return tryOpenCustoms()
end)
