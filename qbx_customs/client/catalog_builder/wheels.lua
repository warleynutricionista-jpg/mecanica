local VehicleClass = require 'client.enums.VehicleClass'
local WheelType = require 'client.enums.WheelType'
local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

local function isWheelTypeAllowed(wheelType)
    local class = GetVehicleClass(session.vehicle)
    if class == VehicleClass.Cycles then return false end
    if class == VehicleClass.Motorcycles then
        return wheelType == WheelType.Bike
    end
    if class == VehicleClass.OpenWheels then
        return wheelType == WheelType.OpenWheel
    end
    return true
end

function builders.buildWheelOptions()
    local options = {}
    local vehicle = session.vehicle
    local originalWheelType = GetVehicleWheelType(vehicle)
    local currentFront = GetVehicleMod(vehicle, 23)
    local currentRear = GetVehicleMod(vehicle, 24)

    for _, wheel in ipairs(config.wheels) do
        if not isWheelTypeAllowed(wheel.id) then goto continue end

        SetVehicleWheelType(vehicle, wheel.id)
        local modCount = GetNumVehicleMods(vehicle, 23)
        if modCount <= 0 then goto continue end

        local choices = {}
        for index = 0, modCount - 1 do
            local textLabel = GetModTextLabel(vehicle, 23, index)
            local label = textLabel and GetLabelText(textLabel) or nil
            if not label or label == 'NULL' then
                label = ('%s %d'):format(wheel.label, index + 1)
            end

            choices[#choices + 1] = common.createChoice(
                ('wheel:%s:%s'):format(wheel.id, index),
                label,
                originalWheelType == wheel.id and currentFront == index,
                actions.getPrice('cosmetic'),
                function(targetVehicle)
                    SetVehicleWheelType(targetVehicle, wheel.id)
                    SetVehicleMod(targetVehicle, 23, index, false)
                    if GetVehicleClass(targetVehicle) ~= VehicleClass.Motorcycles then
                        SetVehicleMod(targetVehicle, 24, -1, false)
                    end
                end,
                locale('menus.wheels.installed', wheel.label, label),
                index + 1
            )
        end

        options[#options + 1] = {
            id = ('wheelcat:%s'):format(wheel.id),
            label = wheel.label,
            icon = '◎',
            asset = 'WheelType',
            group = 'Rodas',
            price = actions.getPrice('cosmetic'),
            priceMod = 'cosmetic',
            choices = choices,
            disabled = false,
        }

        ::continue::
    end

    SetVehicleWheelType(vehicle, originalWheelType)
    SetVehicleMod(vehicle, 23, currentFront, false)
    SetVehicleMod(vehicle, 24, currentRear, false)

    if GetVehicleClass(vehicle) == VehicleClass.Motorcycles and currentRear >= -1 then
        local modCount = GetNumVehicleMods(vehicle, 24)
        if modCount > 0 then
            local choices = {}
            for index = 0, modCount - 1 do
                local textLabel = GetModTextLabel(vehicle, 24, index)
                local label = textLabel and GetLabelText(textLabel) or nil
                if not label or label == 'NULL' then
                    label = ('%s %d'):format(locale('menus.wheels.bikeRear'), index + 1)
                end

                choices[#choices + 1] = common.createChoice(
                    ('wheelrear:%s'):format(index),
                    label,
                    currentRear == index,
                    actions.getPrice('cosmetic'),
                    function(targetVehicle)
                        SetVehicleWheelType(targetVehicle, WheelType.Bike)
                        SetVehicleMod(targetVehicle, 24, index, false)
                    end,
                    locale('menus.wheels.installed', locale('menus.wheels.bikeRear'), label),
                    index + 1
                )
            end

            options[#options + 1] = {
                id = 'wheelcat:rear',
                label = locale('menus.wheels.bikeRear'),
                icon = '◎',
                asset = 'BikeWheel',
                group = 'Rodas',
                price = actions.getPrice('cosmetic'),
                priceMod = 'cosmetic',
                choices = choices,
                disabled = false,
            }
        end
    end

    common.sortOptions(options)
    return options
end

return builders
