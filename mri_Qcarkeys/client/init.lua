local VehicleKeys = require 'client.interface'
local Hotwire = require 'client.modules.hotwire'
local Steal = require 'client.modules.steal'
local LockPick = require 'client.modules.lockpick'
local Utils = require 'client.modules.utils'
local KeyManagement = require 'client.modules.keys'
local _ = require 'client.modules.entity_checks'

local function debugLog(message, ...)
    Shared.DebugPrint(message, ...)
end

local function trackCreatedVehicle(entity)
    if not Config.AdminSpawnFallback then return end
    if entity == 0 or not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId <= 0 then return end

    VehicleKeys.pendingSpawnClaims[netId] = {
        createdAt = GetGameTimer(),
        model = GetEntityModel(entity)
    }

    SetTimeout(15000, function()
        VehicleKeys.pendingSpawnClaims[netId] = nil
    end)
end

local function requestSpawnKeyFallback(vehicle, reason)
    if not Config.AdminSpawnFallback or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local identity = Utils:GetVehicleIdentity(vehicle)
    if not identity or not identity.netId then return end
    if VehicleKeys.hasKey or KeyManagement:HasKey(vehicle, identity.plateKey) then return end

    local tracked = VehicleKeys.pendingSpawnClaims[identity.netId]
    if not tracked or (GetGameTimer() - tracked.createdAt) > 15000 then return end

    debugLog('fallback spawn detection net=%s plate=%s reason=%s', identity.netId, identity.plateKey or 'nil', reason)
    TriggerServerEvent('mm_carkeys:server:claimFallbackSpawnKeys', identity.netId, {
        category = 'admin',
        temporary = true,
        reason = reason,
        plate = identity.plate,
    })
    VehicleKeys.pendingSpawnClaims[identity.netId] = nil
end

function VehicleKeys:Init(plate)
    if plate then self.currentVehiclePlate = plate end
    if self.currentVehicle == 0 or not VehicleKeys.isInDrivingSeat then
        if VehicleKeys.showTextUi then
            lib.hideTextUI()
            VehicleKeys.showTextUi = false
        end
        self.hasKey = false
        return
    end
    if Entity(VehicleKeys.currentVehicle) and Entity(VehicleKeys.currentVehicle).state.isVehicleShopEntity then return end

    local vehClass = GetVehicleClass(self.currentVehicle)
    if Shared.blacklistedClasses[vehClass] then return end

    self.hasKey = KeyManagement:SyncCurrentVehicleState()
    self.isEngineRunning = self.hasKey and GetIsVehicleEngineRunning(self.currentVehicle) or false

    if not self.hasKey then
        requestSpawnKeyFallback(self.currentVehicle, 'driver-seat')
    end

    if not self.hasKey and not self.showTextUi and Shared.hotwire.available then
        lib.showTextUI('Ligação direta', {
            position = 'right-center',
            icon = 'h',
        })
        self.showTextUi = true
        Hotwire:SetupHotwire()
    elseif self.hasKey and self.showTextUi then
        lib.hideTextUI()
        self.showTextUi = false
    end
end

if Shared.Ready then
    lib.onCache('vehicle', function(value)
        if value and IsThisModelABicycle(GetEntityModel(value)) then return end
        if value then
            VehicleKeys.currentVehicle = value
            VehicleKeys.isInDrivingSeat = GetPedInVehicleSeat(value, -1) == cache.ped
            local identity = Utils:GetVehicleIdentity(value)
            VehicleKeys.currentVehiclePlate = identity and identity.plateKey or false
        else
            if Shared.keepVehicleEngineOn and VehicleKeys.isInDrivingSeat and VehicleKeys.isEngineRunning then
                SetVehicleEngineOn(cache.vehicle, true, true, false)
                VehicleKeys.isEngineRunning = false
            end
            VehicleKeys.currentVehicle = 0
            VehicleKeys.isInDrivingSeat = false
            VehicleKeys.currentVehiclePlate = false
            VehicleKeys:Thread()
        end
        VehicleKeys:Init()
    end)

    lib.onCache('seat', function(value)
        if value == nil then return end
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 and IsThisModelABicycle(GetEntityModel(vehicle)) then return end
        VehicleKeys.isInDrivingSeat = value == -1
        VehicleKeys:Init()
    end)

    lib.onCache('weapon', function(value)
        if not value then return end
        VehicleKeys.currentWeapon = value
        if not Shared.steal.available then return end
        Steal:CarjackInit()
    end)
end

function VehicleKeys:Thread()
    CreateThread(function()
        while self.currentVehicle == 0 do
            local wait = 200
            if VehicleKeys.currentVehicle ~= 0 then wait = 500 end
            local entering = GetVehiclePedIsTryingToEnter(cache.ped)
            if entering ~= 0 then
                wait = 500
                local driver = GetPedInVehicleSeat(entering, -1)
                if not Shared.playerDraggable and IsPedAPlayer(driver) then
                    SetPedCanBeDraggedOut(driver, false)
                end
                if driver ~= 0 and not IsPedAPlayer(driver) then
                    if Shared.LockNPCVehicle then
                        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(entering), 2)
                        TaskSmartFleePed(driver, cache.ped, -1, -1, false, false)
                    end
                    if Shared.grab.alive or IsEntityDead(driver) then
                        Steal:GrabKey(entering)
                    end
                end
            end
            Wait(wait)
        end
    end)
end

exports('GiveTempKeys', function(plate)
    exports.mri_Qcarkeys:GiveTemporaryKeys(plate)
end)

exports('RemoveTempKeys', function(plate)
    exports.mri_Qcarkeys:RemoveKeys(plate)
end)

exports('GiveKeyItem', function(plate)
    if not plate then return end
    TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', plate)
end)

exports('RemoveKeyItem', function(plate)
    if not plate then return end
    TriggerServerEvent('mm_carkeys:server:removevehiclekeys', plate)
end)

exports('GiveTemporaryKeys', function(vehicleOrPlate, metadata)
    local vehicle = type(vehicleOrPlate) == 'number' and vehicleOrPlate or nil
    local payload = metadata or {}
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        payload.netId = NetworkGetNetworkIdFromEntity(vehicle)
        payload.plate = GetVehicleNumberPlateText(vehicle)
    else
        payload.plate = vehicleOrPlate
    end
    TriggerServerEvent('mm_carkeys:server:giveTemporaryKeys', payload)
end)

exports('GivePermanentKeys', function(vehicleOrPlate, metadata)
    local vehicle = type(vehicleOrPlate) == 'number' and vehicleOrPlate or nil
    local payload = metadata or {}
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        payload.netId = NetworkGetNetworkIdFromEntity(vehicle)
        payload.plate = GetVehicleNumberPlateText(vehicle)
    else
        payload.plate = vehicleOrPlate
    end
    TriggerServerEvent('mm_carkeys:server:givePermanentKeys', payload)
end)

exports('RemoveKeys', function(vehicleOrPlate)
    local vehicle = type(vehicleOrPlate) == 'number' and vehicleOrPlate or nil
    local payload = {}
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        payload.netId = NetworkGetNetworkIdFromEntity(vehicle)
        payload.plate = GetVehicleNumberPlateText(vehicle)
    else
        payload.plate = vehicleOrPlate
    end
    TriggerServerEvent('mm_carkeys:server:removeKeys', payload)
end)

exports('HasKeys', function(vehicleOrPlate)
    local vehicle = type(vehicleOrPlate) == 'number' and vehicleOrPlate or nil
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return KeyManagement:HasKey(vehicle)
    end
    return KeyManagement:HasPermanentKey(vehicleOrPlate) or KeyManagement:HasTemporaryKey(vehicleOrPlate)
end)

exports('HaveTemporaryKey', function(plate)
    if not plate then return end
    return KeyManagement:HasTemporaryKey(plate)
end)

exports('HavePermanentKey', function(plate)
    if not plate then return end
    return KeyManagement:HasPermanentKey(plate)
end)

exports('RegisterSpawnedVehicle', function(vehicleEntity, options)
    if not vehicleEntity or vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then return false end
    TriggerServerEvent('mm_carkeys:server:registerSpawnedVehicle', NetworkGetNetworkIdFromEntity(vehicleEntity), options or {})
    return true
end)

exports('AssignKeysOnServiceSpawn', function(vehicleEntity, options)
    if not vehicleEntity or vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then return false end
    local payload = options or {}
    payload.category = 'service'
    payload.temporary = payload.temporary ~= false
    TriggerServerEvent('mm_carkeys:server:registerSpawnedVehicle', NetworkGetNetworkIdFromEntity(vehicleEntity), payload)
    return true
end)

exports('AssignKeysOnAdminSpawn', function(vehicleEntity, options)
    if not vehicleEntity or vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then return false end
    local payload = options or {}
    payload.category = 'admin'
    payload.temporary = payload.temporary ~= false
    TriggerServerEvent('mm_carkeys:server:registerSpawnedVehicle', NetworkGetNetworkIdFromEntity(vehicleEntity), payload)
    return true
end)

AddEventHandler('entityCreated', trackCreatedVehicle)

RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
    if VehicleKeys.currentVehicle ~= 0 then
        LockPick:LockPickEngine(isAdvanced)
    else
        LockPick:LockPickDoor(isAdvanced)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() == resource and VehicleKeys.showTextUi then
        lib.hideTextUI()
        VehicleKeys.showTextUi = false
    end
end)
