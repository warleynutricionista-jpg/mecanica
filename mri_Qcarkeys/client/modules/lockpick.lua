local VehicleKeys = require 'client.interface'
local VehicleSecurity = require 'client.modules.vehicle_security'
local Action = require 'client.modules.action_helper'

local LockPick = { lockpicking = false, activeToken = nil }

function LockPick:Minigame()
    if Shared.lockpick.minigameScript == 'inside-lockpicking' then
        local result = exports['inside-lockpicking']:StartLockPicking({ difficulty = 'easy', requiredAmount = 2 })
        return result == 'success'
    end
    return lib.skillCheck('easy')
end

function LockPick:BreakLockPick(isAdvanced)
    local chance = math.random()
    local canBreak = isAdvanced and chance <= Shared.lockpick.advancedBreakChance or chance <= Shared.lockpick.breakChance
    if canBreak then
        TriggerServerEvent('mm_carkeys:server:removelockpick', isAdvanced and Shared.items.advancedLockpick or Shared.items.lockpick)
    end
end

function LockPick:RunServerStages(vehicle, mode)
    local ok, payload = lib.callback.await('mm_carkeys:server:beginLockpick', false, NetworkGetNetworkIdFromEntity(vehicle), mode)
    if not ok then
        local map = {
            too_far = Shared.text.tooFar,
            busy = Shared.text.actionBlocked,
            permanent_damage = Shared.text.mechanicRequired
        }
        Action:Notify(map[payload] or Shared.text.actionBlocked, 'error')
        return false, payload
    end

    self.activeToken = payload.token
    local stage = payload.stage
    local required = payload.requiredStages

    while stage <= required do
        local label = Shared.text.lockpickProgress:format(stage, required)
        local progress = Action:RunProgress({
            label = label,
            duration = Shared.lockpick.stageDuration,
            anim = Action:PlayMechanicAnim()
        })

        if not progress then
            TriggerServerEvent('mm_carkeys:server:cancelAction', self.activeToken)
            self.activeToken = nil
            return false, 'cancelled'
        end

        local stageResult = self:Minigame()
        local serverOk, response = lib.callback.await('mm_carkeys:server:lockpickStage', false, self.activeToken, stageResult)
        if serverOk and response == 'completed' then
            self.activeToken = nil
            return true
        end

        if type(response) == 'table' and response.stage then
            stage = response.stage
        else
            self.activeToken = nil
            return false, response
        end
    end

    self.activeToken = nil
    return false, 'failed'
end

function LockPick:LockPickDoor(isAdvanced)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3.0, false)
    if not vehicle or GetVehicleDoorLockStatus(vehicle) == 1 then return end
    if self.lockpicking then return end

    self.lockpicking = true
    local result, reason = self:RunServerStages(vehicle, 'door')
    TriggerServerEvent('hud:server:GainStress', Shared.lockpick.stressIncrease)
    self:BreakLockPick(isAdvanced)
    self.lockpicking = false

    if result then
        local plate = GetVehicleNumberPlateText(vehicle)
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
        TriggerServerEvent('mm_carkeys:server:setVehicleStatus', plate, Shared.vehicleState.states.breached)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        Action:Notify(Shared.text.vehicleUnlocked, 'success')
        return
    end

    if reason == 'cancelled' then
        Action:Notify(Shared.text.lockpickCancelled, 'error')
    else
        VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, Shared.ignition.lockpickFailDamage)
        Action:Notify(Shared.text.lockpickFailed, 'error')
    end
end

function LockPick:LockPickEngine(isAdvanced)
    if VehicleKeys.currentVehicle == 0 or GetIsVehicleEngineRunning(VehicleKeys.currentVehicle) then return end
    if self.lockpicking then return end

    self.lockpicking = true
    local result, reason = self:RunServerStages(VehicleKeys.currentVehicle, 'engine')
    TriggerServerEvent('hud:server:GainStress', Shared.lockpick.stressIncrease)
    self:BreakLockPick(isAdvanced)
    self.lockpicking = false

    if result then
        SetVehicleEngineOn(VehicleKeys.currentVehicle, true, true, true)
        VehicleKeys.isEngineRunning = true
        return
    end

    if reason == 'cancelled' then
        Action:Notify(Shared.text.lockpickCancelled, 'error')
    else
        VehicleSecurity:ApplyIgnitionFailureDamage(VehicleKeys.currentVehicle, Shared.ignition.lockpickFailDamage)
        Action:Notify(Shared.text.lockpickFailed, 'error')
    end
end

return LockPick
