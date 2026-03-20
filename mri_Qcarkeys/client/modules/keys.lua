local VehicleKeys = require 'client.interface'
local InventoryBridge = require 'bridge.inventory.client'
local VehicleIntegrations = require 'client.modules.vehicle_integrations'
local Utils = require 'client.modules.utils'

local KeyManagement = {
    getItemInfo = Shared.Inventory == 'qb' and function(item) return item.info end or function(item) return item.metadata end
}

local function normalizeNetId(netId)
    if type(netId) ~= 'number' or netId <= 0 then return nil end
    return netId
end

function KeyManagement:SetVehicleKeys()
    VehicleKeys.playerKeys = {}
    local PlayerItems = InventoryBridge:GetPlayerItems()
    if not PlayerItems then return end
    for _, item in pairs(PlayerItems) do
        local itemInfo = self.getItemInfo(item)
        if itemInfo and item.name == 'vehiclekey' then
            VehicleKeys.playerKeys[#VehicleKeys.playerKeys + 1] = Utils:GetPlateKey(itemInfo.plate)
        elseif itemInfo and item.name == 'keybag' then
            for _, v in pairs(itemInfo.plates or {}) do
                VehicleKeys.playerKeys[#VehicleKeys.playerKeys + 1] = Utils:GetPlateKey(v.plate)
            end
        end
    end
end

function KeyManagement:GetKeys()
    lib.callback('mm_carkeys:server:getvehiclekeys', false, function(keysList)
        VehicleKeys.playerTempKeys = keysList or { plates = {}, netIds = {}, meta = {} }
    end)
end

function KeyManagement:HasTemporaryKey(plate, netId)
    local plateKey = Utils:GetPlateKey(plate)
    local normalizedNetId = normalizeNetId(netId)
    return (plateKey ~= 'undefined' and VehicleKeys.playerTempKeys.plates[plateKey] ~= nil)
        or (normalizedNetId and VehicleKeys.playerTempKeys.netIds[normalizedNetId] ~= nil)
end

function KeyManagement:HasPermanentKey(plate)
    local plateKey = Utils:GetPlateKey(plate)
    return plateKey ~= 'undefined' and lib.table.contains(VehicleKeys.playerKeys, plateKey)
end

function KeyManagement:HasKey(vehicle, plate)
    local identity = vehicle and Utils:GetVehicleIdentity(vehicle) or nil
    local plateKey = plate or identity and identity.plateKey or nil
    local netId = identity and identity.netId or nil
    return self:HasPermanentKey(plateKey) or self:HasTemporaryKey(plateKey, netId)
end

function KeyManagement:SyncCurrentVehicleState()
    if not VehicleKeys.currentVehicle or VehicleKeys.currentVehicle == 0 then
        VehicleKeys.hasKey = false
        return false
    end

    VehicleKeys.hasKey = self:HasKey(VehicleKeys.currentVehicle, VehicleKeys.currentVehiclePlate)
    return VehicleKeys.hasKey
end

function KeyManagement:ApplyTempKey(payload)
    if type(payload) ~= 'table' then
        payload = { plate = payload }
    end

    local plateKey = Utils:GetPlateKey(payload.plate)
    local netId = normalizeNetId(payload.netId)

    if plateKey ~= 'undefined' then
        VehicleKeys.playerTempKeys.plates[plateKey] = true
        VehicleKeys.playerTempKeys.meta[plateKey] = payload
    end

    if netId then
        VehicleKeys.playerTempKeys.netIds[netId] = true
    end

    if VehicleKeys.currentVehicle and VehicleKeys.currentVehicle ~= 0 and self:HasKey(VehicleKeys.currentVehicle, VehicleKeys.currentVehiclePlate) then
        VehicleKeys:Init(plateKey ~= 'undefined' and plateKey or VehicleKeys.currentVehiclePlate)
        SetVehicleEngineOn(VehicleKeys.currentVehicle, true, false, true)
        VehicleKeys.isEngineRunning = true
    end
end

function KeyManagement:RemoveTempKey(payload)
    if type(payload) ~= 'table' then
        payload = { plate = payload }
    end

    local plateKey = Utils:GetPlateKey(payload.plate)
    local netId = normalizeNetId(payload.netId)

    if plateKey ~= 'undefined' then
        VehicleKeys.playerTempKeys.plates[plateKey] = nil
        VehicleKeys.playerTempKeys.meta[plateKey] = nil
    end

    if netId then
        VehicleKeys.playerTempKeys.netIds[netId] = nil
    end

    if VehicleKeys.currentVehicle and VehicleKeys.currentVehicle ~= 0 and not self:HasKey(VehicleKeys.currentVehicle, VehicleKeys.currentVehiclePlate) then
        VehicleKeys.hasKey = false
        SetVehicleEngineOn(VehicleKeys.currentVehicle, false, false, true)
        VehicleKeys.isEngineRunning = false
        VehicleKeys:Init(VehicleKeys.currentVehiclePlate)
    end
end

function KeyManagement:ToggleVehicleLock(vehicle, remote)
    local hash = joaat('p_car_keys_01')
    local animDict = 'anim@mp_player_intmenu@key_fob@'

    lib.requestAnimDict(animDict)
    lib.requestModel(hash)

    local keyProp = CreateObject(hash, GetEntityCoords(cache.ped), false, false, false)
    TaskPlayAnim(cache.ped, animDict, 'fob_click', 3.0, 3.0, -1, 49, 0, false, false, false)
    SetEntityCollision(keyProp, false, false)
    AttachEntityToEntity(keyProp, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.10, 0.02, 0, 48.10, 23.14, 24.14, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(keyProp)
    SetTimeout(1500, function()
        ClearPedTasks(cache.ped)
        DeleteEntity(keyProp)
        RemoveAnimDict(animDict)
    end)

    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, 'lock', 0.3)
    NetworkRequestControlOfEntity(vehicle)
    while not NetworkHasControlOfEntity(vehicle) do Wait(0) end
    local vehLockStatus = GetVehicleDoorLockStatus(vehicle)
    if vehLockStatus == 1 then
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 4)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        lib.notify({ description = Shared.text.vehicleLocked, type = 'error' })
    else
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        lib.notify({ description = Shared.text.vehicleUnlocked, type = 'success' })
    end

    if remote or not Shared.toggleLightsOnlyRemote then
        SetVehicleLights(vehicle, 2)
        Wait(250)
        SetVehicleLights(vehicle, 1)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        Wait(300)
    end
end

RegisterCommand('togglelocks', function()
    if VehicleKeys.currentVehicle == 0 then
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not vehicle then return end
        if KeyManagement:HasKey(vehicle) then
            KeyManagement:ToggleVehicleLock(vehicle)
        end
        return
    end

    if KeyManagement:HasKey(VehicleKeys.currentVehicle, VehicleKeys.currentVehiclePlate) then
        KeyManagement:ToggleVehicleLock(VehicleKeys.currentVehicle)
    end
end, false)

RegisterKeyMapping('togglelocks', 'Trancar/Destrancar veículo', 'keyboard', 'L')

if Shared.keepKeysInVehicle then
    CreateThread(function()
        local delay
        while true do
            delay = 1000
            if VehicleKeys.currentVehicle and cache.vehicle then
                local keysInVehicle = Entity(VehicleKeys.currentVehicle).state['keysIn']
                if not keysInVehicle then
                    SetVehicleEngineOn(VehicleKeys.currentVehicle, false, false, true)
                    VehicleKeys.isEngineRunning = false
                    delay = 5
                end
            end
            Wait(delay)
        end
    end)
end

RegisterCommand('mri:engine', function()
    if not VehicleKeys.currentVehicle or VehicleKeys.currentVehicle == 0 then return end

    local playerPed = cache.ped
    local seatPed = GetPedInVehicleSeat(VehicleKeys.currentVehicle, -1)
    if seatPed ~= playerPed then return end

    local engineOn = GetIsVehicleEngineRunning(VehicleKeys.currentVehicle)
    local vehiclePlate = VehicleKeys.currentVehiclePlate
    if engineOn then
        SetVehicleEngineOn(VehicleKeys.currentVehicle, false, false, true)
        VehicleKeys.isEngineRunning = false
        if Shared.keepKeysInVehicle then
            Entity(VehicleKeys.currentVehicle).state:set('keysIn', false, true)
            TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', vehiclePlate)
            TriggerEvent('mm_carkeys:client:removetempkeys', { plate = vehiclePlate, netId = NetworkGetNetworkIdFromEntity(VehicleKeys.currentVehicle) })
        end
        return
    end

    if (not Shared.keepKeysInVehicle and VehicleKeys.hasKey) or Entity(VehicleKeys.currentVehicle).state['keysIn'] or exports.mri_Qcarkeys:HavePermanentKey(vehiclePlate) or KeyManagement:HasTemporaryKey(vehiclePlate, NetworkGetNetworkIdFromEntity(VehicleKeys.currentVehicle)) then
        if not VehicleIntegrations:CanUseIgnition(VehicleKeys.currentVehicle, true) then return end

        SetVehicleEngineOn(VehicleKeys.currentVehicle, true, false, true)
        VehicleKeys.isEngineRunning = true
        if Shared.keepKeysInVehicle then
            Entity(VehicleKeys.currentVehicle).state:set('keysIn', true, true)
            TriggerEvent('mm_carkeys:client:removekeyitem')
            TriggerEvent('mm_carkeys:client:addtempkeys', { plate = vehiclePlate, netId = NetworkGetNetworkIdFromEntity(VehicleKeys.currentVehicle) })
        end
    end
end, false)

RegisterKeyMapping('mri:engine', 'Ligar/desligar veículo', 'keyboard', 'Z')

lib.callback.register('mm_carkeys:client:getplate', function()
    if VehicleKeys.currentVehicle == 0 then return false end
    return VehicleKeys.currentVehiclePlate
end)

lib.callback.register('mm_carkeys:client:havekey', function(kind, plateOrData)
    local plate = type(plateOrData) == 'table' and plateOrData.plate or plateOrData
    local netId = type(plateOrData) == 'table' and plateOrData.netId or nil
    if kind == 'temp' then
        return KeyManagement:HasTemporaryKey(plate, netId)
    elseif kind == 'perma' then
        return KeyManagement:HasPermanentKey(plate)
    end
end)

RegisterNetEvent('mm_carkeys:client:addtempkeys', function(payload)
    KeyManagement:ApplyTempKey(payload)
end)

RegisterNetEvent('qb-vehiclekeys:client:AddKeys', function(plate)
    exports.mri_Qcarkeys:GiveTemporaryKeys(plate)
end)

RegisterNetEvent('mm_carkeys:client:removetempkeys', function(payload)
    KeyManagement:RemoveTempKey(payload)
end)

RegisterNetEvent('mm_carkeys:client:setplayerkey', function(plate)
    if not plate then return end
    TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', plate)
end)

RegisterNetEvent('mm_carkeys:client:removeplayerkey', function(plate)
    if not plate then
        return lib.notify({ description = 'Nenhuma placa de veículo encontrada', type = 'error' })
    end
    TriggerServerEvent('mm_carkeys:server:removevehiclekeys', plate)
end)

RegisterNetEvent('mm_carkeys:client:givekeyitem', function()
    if VehicleKeys.currentVehicle == 0 then
        return lib.notify({ description = 'You are not inside any vehicle', type = 'error' })
    end

    if lib.progressBar({
        label = 'Procurando as chaves...',
        duration = 5000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true }
    }) then
        TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', VehicleKeys.currentVehiclePlate)
    else
        lib.notify({ description = Shared.text.actionCancelled, type = 'error' })
    end
end)

RegisterNetEvent('mm_carkeys:client:removekeyitem', function()
    if VehicleKeys.currentVehicle == 0 then
        return lib.notify({ description = 'Você não está dentro de nenhum veículo', type = 'error' })
    end
    TriggerServerEvent('mm_carkeys:server:removevehiclekeys', VehicleKeys.currentVehiclePlate)
end)

RegisterNetEvent('mm_carkeys:client:stackkeys', function()
    if lib.progressBar({
        label = 'Juntando as chaves...',
        duration = 5000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@amb@business@weed@weed_inspecting_high_dry@',
            clip = 'weed_inspecting_high_base_inspector'
        },
        disable = { car = true, move = true, combat = true }
    }) then
        TriggerServerEvent('mm_carkeys:server:stackkeys')
    else
        lib.notify({ description = 'Ação cancelada', type = 'error' })
    end
end)

RegisterNetEvent('mm_carkeys:client:unstackkeys', function()
    if lib.progressBar({
        label = 'Separando as chaves...',
        duration = 5000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        anim = {
            dict = 'anim@amb@business@weed@weed_inspecting_high_dry@',
            clip = 'weed_inspecting_high_base_inspector'
        },
        disable = { car = true, move = true, combat = true }
    }) then
        TriggerServerEvent('mm_carkeys:server:unstackkeys')
    else
        lib.notify({ description = 'Ação cancelada', type = 'error' })
    end
end)

return KeyManagement
