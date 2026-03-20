if Shared.Framework == 'qbx' then
    local KeyManagement = require 'client.modules.keys'
    local VehicleKeys = require 'client.interface'
    local Utils = require 'client.modules.utils'

    local function setupData()
        VehicleKeys.currentVehicle = cache.vehicle or 0
        if cache.vehicle then
            VehicleKeys.isInDrivingSeat = GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped
            VehicleKeys.currentVehiclePlate = Utils:GetPlateKey(GetVehicleNumberPlateText(cache.vehicle))
        end
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        KeyManagement:SetVehicleKeys()
        VehicleKeys:Thread()
        VehicleKeys:Init()
        KeyManagement:GetKeys()
    end)

    RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate, isBuying)
        if not plate then return end
        if isBuying then
            TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', plate)
        else
            TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', plate)
        end
    end)

    AddEventHandler('onResourceStart', function(resource)
        if GetCurrentResourceName() == resource and LocalPlayer.state.isLoggedIn then
            setupData()
            KeyManagement:SetVehicleKeys()
            VehicleKeys:Thread()
            VehicleKeys:Init()
            KeyManagement:GetKeys()
        end
    end)

    AddEventHandler('ox_inventory:updateInventory', function()
        KeyManagement:SetVehicleKeys()
        VehicleKeys:Init()
    end)

    exports.ox_inventory:displayMetadata({ platestxt = 'Vehicle Plates' })
end
