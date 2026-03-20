local Utils = {}
local VehicleKeys = require 'client.interface'

function Utils:IsBlacklistedWeapon()
    if VehicleKeys.currentWeapon then
        for _, v in pairs(Shared.BlackListedWeapon) do
            if VehicleKeys.currentWeapon == joaat(v) then
                return true
            end
        end
    end
    return false
end

function Utils:GetPedsInVehicle(vehicle)
    if not vehicle then return end
    local otherPeds = {}
    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if not IsPedAPlayer(pedInSeat) and pedInSeat ~= 0 then
            otherPeds[#otherPeds + 1] = pedInSeat
        end
    end
    return otherPeds
end

function Utils:NormalizePlate(plate)
    return Shared.NormalizePlate(plate)
end

function Utils:GetPlateKey(plate)
    return Shared.GetPlateKey(plate) or 'undefined'
end

function Utils:RemoveSpecialCharacter(txt)
    return self:GetPlateKey(txt)
end

function Utils:GetVehicleIdentity(vehicle)
    return Shared.GetVehicleIdentity(vehicle)
end

return Utils
