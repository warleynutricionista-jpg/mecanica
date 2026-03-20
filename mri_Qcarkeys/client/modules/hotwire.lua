local VehicleKeys = require 'client.interface'
local VehicleSecurity = require 'client.modules.vehicle_security'
local Action = require 'client.modules.action_helper'

local Hotwire = {
    isHotwiring = false,
    activeVehicle = 0,
    activeToken = nil
}

function Hotwire:ResetState(showCancelledMessage)
    self.isHotwiring = false
    self.activeVehicle = 0
    if self.activeToken then
        Action:CancelServerAction(self.activeToken)
        self.activeToken = nil
    end
    if lib.progressActive() then lib.cancelProgress() end
    if showCancelledMessage then Action:Notify(Shared.text.actionCancelled, 'error') end
end

function Hotwire:CanContinueHotwire(vehicle)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and VehicleKeys.currentVehicle == vehicle
        and IsPedInVehicle(cache.ped, vehicle, false) and GetPedInVehicleSeat(vehicle, -1) == cache.ped
        and not IsEntityDead(cache.ped)
end

function Hotwire:RunHotwireStage(label, duration, vehicle)
    local completed = Action:RunProgress({
        label = label,
        duration = duration,
        disable = { car = true, move = true, combat = true },
        anim = Action:PlayMechanicAnim()
    })
    return completed and self:CanContinueHotwire(vehicle)
end

function Hotwire:HotwireHandler()
    if self.isHotwiring or VehicleKeys.currentVehicle == 0 or not VehicleKeys.isInDrivingSeat then return end

    local vehicle = VehicleKeys.currentVehicle
    local ok, payload = lib.callback.await('mm_carkeys:server:beginHotwire', false, NetworkGetNetworkIdFromEntity(vehicle))
    if not ok then
        local map = {
            missing_item = Shared.text.missingHotwireTool,
            permanent_damage = Shared.text.mechanicRequired,
            too_far = Shared.text.tooFar,
            busy = Shared.text.actionBlocked
        }
        Action:Notify(map[payload] or Shared.text.actionBlocked, 'error')
        return
    end

    lib.notify({ description = Shared.text.hotwireToolConsumed, type = 'inform' })

    self.isHotwiring = true
    self.activeVehicle = vehicle
    self.activeToken = payload.token

    local duration = payload.duration
    local stageOne = math.floor(duration * 0.45)
    local stageTwo = duration - stageOne

    local firstStage = self:RunHotwireStage(Shared.hotwire.stageOneLabel, stageOne, vehicle)
    local secondStage = firstStage and self:RunHotwireStage(Shared.hotwire.stageTwoLabel, stageTwo, vehicle)
    local minigameOk = secondStage and VehicleSecurity:RunHotwireMinigame() or false

    local success, reason = lib.callback.await('mm_carkeys:server:completeHotwire', false, self.activeToken, minigameOk)
    TriggerServerEvent('hud:server:GainStress', Shared.hotwire.stressIncrease)

    self.activeToken = nil
    self.isHotwiring = false
    self.activeVehicle = 0

    if success then
        SetVehicleEngineOn(vehicle, true, false, true)
        VehicleKeys.isEngineRunning = true
        Action:Notify(Shared.text.hotwireSuccess, 'success')
        return
    end

    VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, Shared.ignition.hotwireFailDamage)
    if reason == 'permanent_damage' then
        Action:Notify(Shared.text.irreversibleElectricalDamage, 'error')
        if Shared.hotwire.blockEngineOnPermanentDamage then
            SetVehicleEngineOn(vehicle, false, false, true)
        end
    else
        Action:Notify(Shared.text.hotwireFailed, 'error')
    end
end

function Hotwire:SetupHotwire()
    CreateThread(function()
        while VehicleKeys.currentVehicle ~= 0 and not VehicleKeys.hasKey do
            SetVehicleEngineOn(VehicleKeys.currentVehicle, false, false, true)
            VehicleKeys.isEngineRunning = false
            if IsControlJustPressed(0, 74) then
                self:HotwireHandler()
            end
            Wait(5)
        end
    end)
end

return Hotwire
