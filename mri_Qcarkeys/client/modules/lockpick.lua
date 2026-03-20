local VehicleKeys = require 'client.interface'
local VehicleSecurity = require 'client.modules.vehicle_security'
local Action = require 'client.modules.action_helper'

local LockPick = { lockpicking = false, activeToken = nil }

function LockPick:GetLockpickItem(isAdvanced)
    local items = Shared.items or {}
    local itemName = isAdvanced and items.advancedLockpick or items.lockpick

    if type(itemName) ~= 'string' or itemName == '' then
        Shared.DebugPrint('lockpick item not configured for advanced=%s', tostring(isAdvanced))
        return nil
    end

    return itemName
end

function LockPick:ShouldApplyFailureDamage(reason)
    return reason == 'failed'
end

function LockPick:FinishAttempt(isAdvanced, started)
    if started then
        TriggerServerEvent('hud:server:GainStress', Shared.lockpick.stressIncrease)
        self:BreakLockPick(isAdvanced)
    end

    self.lockpicking = false
end

function LockPick:Minigame(stage, required)
    local difficulty = stage and required and stage >= required and 'medium' or 'easy'

    if Shared.lockpick.minigameScript == 'inside-lockpicking' then
        local result = exports['inside-lockpicking']:StartLockPicking({ difficulty = difficulty, requiredAmount = difficulty == 'medium' and 3 or 2 })
        return result == 'success'
    end

    return lib.skillCheck(difficulty)
end

function LockPick:BreakLockPick(isAdvanced)
    local chance = math.random()
    local canBreak = isAdvanced and chance <= Shared.lockpick.advancedBreakChance or chance <= Shared.lockpick.breakChance
    if not canBreak then return end

    local itemName = self:GetLockpickItem(isAdvanced)
    if not itemName then return end

    TriggerServerEvent('mm_carkeys:server:removelockpick', itemName)
end

function LockPick:RunServerStages(vehicle, mode)
    local ok, payload = lib.callback.await('mm_carkeys:server:beginLockpick', false, NetworkGetNetworkIdFromEntity(vehicle), mode)
    if not ok then
        local map = {
            too_far = Shared.text.tooFar,
            busy = Shared.text.actionBlocked,
            cooldown = Shared.text.lockpickCooldown,
            disabled = Shared.text.lockpickDisabled,
            invalid_vehicle = Shared.text.invalidTarget,
            permanent_damage = Shared.text.mechanicRequired
        }
        Action:Notify(map[payload] or Shared.text.actionBlocked, 'error')
        return false, payload, false
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
            return false, 'cancelled', true
        end

        local stageResult = self:Minigame(stage, required)
        local serverOk, response = lib.callback.await('mm_carkeys:server:lockpickStage', false, self.activeToken, stageResult)
        if serverOk and response == 'completed' then
            self.activeToken = nil
            return true, 'completed', true
        end

        if type(response) == 'table' and response.stage then
            if response.regress then
                Action:Notify(Shared.text.lockpickRegressed or Shared.text.lockpickFailed, 'inform')
            end
            stage = response.stage
        else
            self.activeToken = nil
            return false, response, true
        end
    end

    self.activeToken = nil
    return false, 'failed', true
end

function LockPick:LockPickDoor(isAdvanced)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3.0, false)
    if not vehicle or GetVehicleDoorLockStatus(vehicle) == 1 then return end
    if self.lockpicking then return end

    self.lockpicking = true
    local result, reason, started = self:RunServerStages(vehicle, 'door')
    self:FinishAttempt(isAdvanced, started)

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
    elseif reason == 'too_far' then
        Action:Notify(Shared.text.tooFar, 'error')
    elseif self:ShouldApplyFailureDamage(reason) then
        VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, Shared.ignition.lockpickFailDamage)
        Action:Notify(Shared.text.lockpickFailed, 'error')
    end
end

function LockPick:LockPickEngine(isAdvanced)
    if VehicleKeys.currentVehicle == 0 or GetIsVehicleEngineRunning(VehicleKeys.currentVehicle) then return end
    if not VehicleKeys.isInDrivingSeat then
        Action:Notify(Shared.text.mustBeDriver or Shared.text.invalidTarget, 'error')
        return
    end
    if self.lockpicking then return end

    self.lockpicking = true
    local result, reason, started = self:RunServerStages(VehicleKeys.currentVehicle, 'engine')
    self:FinishAttempt(isAdvanced, started)

    if result then
        SetVehicleEngineOn(VehicleKeys.currentVehicle, true, true, true)
        VehicleKeys.isEngineRunning = true
        return
    end

    if reason == 'cancelled' then
        Action:Notify(Shared.text.lockpickCancelled, 'error')
    elseif reason == 'too_far' then
        Action:Notify(Shared.text.tooFar, 'error')
    elseif self:ShouldApplyFailureDamage(reason) then
        VehicleSecurity:ApplyIgnitionFailureDamage(VehicleKeys.currentVehicle, Shared.ignition.lockpickFailDamage)
        Action:Notify(Shared.text.lockpickFailed, 'error')
    end
end

return LockPick
