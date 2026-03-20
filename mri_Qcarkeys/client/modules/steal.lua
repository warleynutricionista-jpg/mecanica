local VehicleKeys = require 'client.interface'
local Utils = require 'client.modules.utils'
local VehicleSecurity = require 'client.modules.vehicle_security'
local Action = require 'client.modules.action_helper'

local Steal = {
    isCarjacking = false,
    canCarjack = true,
    isRobbingKeys = false,
    npcSearchVehicle = {}
}

function Steal:ToggleCooldown()
    CreateThread(function()
        Wait(5000)
        self.canCarjack = true
        self:CarjackInit()
    end)
end

function Steal:MakePedFlee(target, vehicle)
    local occupants = Utils:GetPedsInVehicle(vehicle)
    for p = 1, #occupants do
        local ped = occupants[p] or 0
        if ped ~= target and DoesEntityExist(ped) then
            CreateThread(function()
                TaskLeaveVehicle(ped, vehicle, 256)
                TaskReactAndFleePed(ped, cache.ped)
                PlayPain(ped, 6, 0)
            end)
        end
    end
end

function Steal:CheckStealStatus(target, vehicle)
    CreateThread(function()
        SetVehicleUndriveable(vehicle, true)
        while self.isCarjacking do
            if not DoesEntityExist(target) then break end
            TaskSetBlockingOfNonTemporaryEvents(target, true)
            local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(target))
            if IsPedDeadOrDying(target, false) or distance > 7.5 then
                SetVehicleUndriveable(vehicle, false)
                if lib.progressActive() then lib.cancelProgress() end
                break
            end
            Wait(25)
        end
    end)
end

function Steal:ArmPedAndAttack(target, vehicle)
    if not DoesEntityExist(target) or IsEntityDead(target) then return false end

    local weaponList = Shared.steal.npcGunWeapons
    if not weaponList or #weaponList == 0 then return false end

    local weapon = weaponList[math.random(1, #weaponList)]
    GiveWeaponToPed(target, joaat(weapon), 120, false, true)
    SetCurrentPedWeapon(target, joaat(weapon), true)
    SetPedAccuracy(target, Shared.steal.npcAccuracy)
    SetPedCombatAttributes(target, 46, true)
    SetPedCombatAbility(target, Shared.steal.npcAggressiveness)
    SetPedAsEnemy(target, true)
    TaskLeaveVehicle(target, vehicle, 256)
    Wait(800)
    TaskCombatPed(target, cache.ped, 0, 16)

    lib.notify({ title = 'Perigo', description = 'O condutor estava armado e reagiu ao assalto!', type = 'error' })
    return true
end

function Steal:CarjackVehicle(target)
    if self.isCarjacking or not self.canCarjack then return end
    if not DoesEntityExist(target) or IsPedAPlayer(target) then return end

    local vehicle = GetVehiclePedIsUsing(target)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    self.isCarjacking = true
    self.canCarjack = false

    local carjackChance = Shared.steal.chance[tostring(GetWeapontypeGroup(cache.weapon))] or 0.5
    VehicleSecurity:TriggerTheftAlert(vehicle, ('Tentativa de carjack em %s'):format(GetVehicleNumberPlateText(vehicle)), 45000)

    if math.random() <= Shared.steal.armedNpcChance and self:ArmPedAndAttack(target, vehicle) then
        self.isCarjacking = false
        self:ToggleCooldown()
        return
    end

    if math.random() > carjackChance then
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 2)
        TaskReactAndFleePed(target, cache.ped)
        self.isCarjacking = false
        self:ToggleCooldown()
        return
    end

    lib.requestAnimDict('missminuteman_1ig_2')
    local stealTime = math.random(Shared.steal.minTime, Shared.steal.maxTime)

    TaskLeaveVehicle(target, vehicle, 256)
    self:MakePedFlee(target, vehicle)

    CreateThread(function()
        Wait(350)
        self:CheckStealStatus(target, vehicle)
        TaskTurnPedToFaceEntity(target, cache.ped, -1)
        TaskPlayAnim(target, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0, false, false, false)
    end)

    if lib.progressBar({ label = Shared.steal.label, duration = stealTime, position = 'bottom', canCancel = true }) then
        self.isCarjacking = false
        StopAnimTask(target, 'missminuteman_1ig_2', 'handsup_base', 1.0)
        TaskSmartFleePed(target, cache.ped, 50, -1, false, false)
        TriggerServerEvent('hud:server:GainStress', Shared.steal.stressIncrease)
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
    else
        self.isCarjacking = false
    end

    self:ToggleCooldown()
    SetVehicleUndriveable(vehicle, false)
end

function Steal:SearchCompartment(vehicle, compartment)
    local ok, payload = lib.callback.await('mm_carkeys:server:beginCompartmentSearch', false, NetworkGetNetworkIdFromEntity(vehicle), compartment)
    if not ok then
        local map = {
            too_far = Shared.text.tooFar,
            closed = Shared.text.compartmentClosed,
            already_searched = Shared.text.alreadySearched,
            busy = Shared.text.actionBlocked
        }
        Action:Notify(map[payload] or Shared.text.actionBlocked, 'error')
        return false
    end

    local token, duration = payload.token, payload.duration
    local progress = Action:RunProgress({
        label = compartment == 'trunk' and 'Revistando porta-malas...' or 'Revistando porta-luvas...',
        duration = duration,
        anim = Action:PlayMechanicAnim()
    })

    local found, reason = lib.callback.await('mm_carkeys:server:completeCompartmentSearch', false, token, progress)
    if found then
        Action:Notify(Shared.text.keyFound, 'success')
        return true
    end

    if reason == 'empty' then
        Action:Notify(Shared.text.emptyCompartment, 'inform')
    elseif reason == 'cancelled' then
        Action:Notify(Shared.text.actionCancelled, 'error')
    else
        Action:Notify(Shared.text.keyNotFound, 'error')
    end

    return false
end

function Steal:SearchNpcForKey(vehicle, driver)
    if driver == 0 or not DoesEntityExist(driver) or IsPedAPlayer(driver) then
        Action:Notify(Shared.text.invalidTarget, 'error')
        return false
    end

    local ok, payload = lib.callback.await('mm_carkeys:server:beginNpcSearch', false,
        NetworkGetNetworkIdFromEntity(vehicle), PedToNet(driver))

    if not ok then
        local map = {
            too_far = Shared.text.tooFar,
            no_key = Shared.text.npcNoKeys,
            invalid_npc = Shared.text.invalidTarget,
            busy = Shared.text.actionBlocked
        }
        Action:Notify(map[payload] or Shared.text.actionBlocked, payload == 'no_key' and 'inform' or 'error')
        return false
    end

    local token, duration = payload.token, payload.duration
    local progress = Action:RunProgress({
        label = 'Revistando NPC...',
        duration = duration,
        anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base' }
    })

    local found, reason = lib.callback.await('mm_carkeys:server:completeNpcSearch', false, token, progress)
    if found then
        Action:Notify(Shared.text.keyFound, 'success')
        return true
    end

    if reason == 'escaped' then
        Action:Notify(Shared.text.npcEscapedWithKeys, 'error')
    elseif reason == 'cancelled' then
        Action:Notify(Shared.text.actionCancelled, 'error')
    else
        Action:Notify(Shared.text.npcNoKeys, 'inform')
    end

    return false
end

function Steal:GrabKey(vehicle)
    if self.isRobbingKeys or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    self.isRobbingKeys = true
    local driver = GetPedInVehicleSeat(vehicle, -1)

    local robbed = lib.progressBar({
        label = Shared.grab.label,
        duration = math.random(Shared.steal.minTime, Shared.steal.maxTime),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true
    })

    if not robbed then
        Action:Notify(Shared.text.actionCancelled, 'error')
        self.isRobbingKeys = false
        return
    end

    if Config.NPCSearch.Enabled and driver ~= 0 and self:SearchNpcForKey(vehicle, driver) then
        self.isRobbingKeys = false
        return
    end

    if Config.SearchKey.Enabled then
        local foundGlove = self:SearchCompartment(vehicle, 'glovebox')
        if not foundGlove then
            self:SearchCompartment(vehicle, 'trunk')
        end
    end

    self.isRobbingKeys = false
end

function Steal:CarjackInit()
    CreateThread(function()
        while VehicleKeys.currentWeapon and VehicleKeys.currentVehicle == 0 do
            local aiming, target = GetEntityPlayerIsFreeAimingAt(cache.playerId)
            if aiming and target and target ~= 0 and DoesEntityExist(target) and IsPedInAnyVehicle(target, false) and not IsEntityDead(target) and not IsPedAPlayer(target) then
                local targetveh = GetVehiclePedIsIn(target, false)
                if targetveh ~= 0 and GetPedInVehicleSeat(targetveh, -1) == target and not Utils:IsBlacklistedWeapon() then
                    if #(GetEntityCoords(cache.ped, true) - GetEntityCoords(target, true)) < 5.0 then
                        self:CarjackVehicle(target)
                        break
                    end
                end
            end
            Wait(200)
        end
    end)
end

return Steal
