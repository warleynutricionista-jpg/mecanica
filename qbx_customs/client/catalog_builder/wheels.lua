local VehicleClass = require 'client.enums.VehicleClass'
local WheelType = require 'client.enums.WheelType'
local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

local function cosmeticPrice()
    return actions.getPrice('cosmetic')
end

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

local function resolveWheelLabel(vehicle, modType, index, fallback)
    local textLabel = GetModTextLabel(vehicle, modType, index)
    if not textLabel or textLabel == '' then
        return fallback
    end

    local label = GetLabelText(textLabel)
    if not label or label == 'NULL' then
        return fallback
    end

    return label
end

local function buildFrontWheelChoices(vehicle, wheelType, wheelLabel, currentFront, currentWheelType, modCount)
    local choices = {}
    local price = cosmeticPrice()

    for index = 0, modCount - 1 do
        local label = resolveWheelLabel(vehicle, 23, index, ('%s %d'):format(wheelLabel, index + 1))
        choices[#choices + 1] = common.createChoice(
            ('wheel:%s:%s'):format(wheelType, index),
            label,
            currentWheelType == wheelType and currentFront == index,
            price,
            function(targetVehicle)
                SetVehicleWheelType(targetVehicle, wheelType)
                SetVehicleMod(targetVehicle, 23, index, false)
                if GetVehicleClass(targetVehicle) ~= VehicleClass.Motorcycles then
                    SetVehicleMod(targetVehicle, 24, -1, false)
                end
            end,
            locale('menus.wheels.installed', wheelLabel, label),
            index + 1
        )
    end

    return choices
end

local function buildRearBikeChoices(vehicle, currentRear)
    local modCount = GetNumVehicleMods(vehicle, 24)
    if modCount <= 0 then
        return nil
    end

    local price = cosmeticPrice()
    local choices = {}

    for index = 0, modCount - 1 do
        local label = resolveWheelLabel(vehicle, 24, index, ('%s %d'):format(locale('menus.wheels.bikeRear'), index + 1))
        choices[#choices + 1] = common.createChoice(
            ('wheelrear:%s'):format(index),
            label,
            currentRear == index,
            price,
            function(targetVehicle)
                SetVehicleWheelType(targetVehicle, WheelType.Bike)
                SetVehicleMod(targetVehicle, 24, index, false)
            end,
            locale('menus.wheels.installed', locale('menus.wheels.bikeRear'), label),
            index + 1
        )
    end

    return common.createOption('wheelcat:rear', locale('menus.wheels.bikeRear'), '◎', 'BikeWheel', 'Rodas', price, 'cosmetic', choices)
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

        options[#options + 1] = common.createOption(
            ('wheelcat:%s'):format(wheel.id),
            wheel.label,
            '◎',
            'WheelType',
            'Rodas',
            cosmeticPrice(),
            'cosmetic',
            buildFrontWheelChoices(vehicle, wheel.id, wheel.label, currentFront, originalWheelType, modCount)
        )

        ::continue::
    end

    SetVehicleWheelType(vehicle, originalWheelType)
    SetVehicleMod(vehicle, 23, currentFront, false)
    SetVehicleMod(vehicle, 24, currentRear, false)

    if GetVehicleClass(vehicle) == VehicleClass.Motorcycles and currentRear >= -1 then
        local rearWheelOption = buildRearBikeChoices(vehicle, currentRear)
        if rearWheelOption then
            options[#options + 1] = rearWheelOption
        end
    end

    common.sortOptions(options)
    return options
end

return builders
