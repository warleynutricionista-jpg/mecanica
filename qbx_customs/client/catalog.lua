local VehicleClass = require 'client.enums.VehicleClass'
local WheelType = require 'client.enums.WheelType'
local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'

local catalog = {}

local categoriesIndex = {}
for _, category in ipairs(config.categories) do
    categoriesIndex[category.id] = category
end

local function cloneCategory(categoryId)
    local data = categoriesIndex[categoryId]
    return {
        id = data.id,
        label = data.label,
        icon = data.icon,
        asset = data.asset,
        description = data.description,
        enabled = false,
        options = {},
    }
end

local function getClassLabel(class)
    local labels = {
        [VehicleClass.Compacts] = 'Compacto',
        [VehicleClass.Sedans] = 'Sedã',
        [VehicleClass.SUVs] = 'SUV',
        [VehicleClass.Coupes] = 'Coupé',
        [VehicleClass.Muscle] = 'Muscle',
        [VehicleClass.SportsClassics] = 'Esportivo clássico',
        [VehicleClass.Sports] = 'Esportivo',
        [VehicleClass.Super] = 'Super',
        [VehicleClass.Motorcycles] = 'Moto',
        [VehicleClass.OffRoad] = 'Off-road',
        [VehicleClass.Industrial] = 'Industrial',
        [VehicleClass.Utility] = 'Utilitário',
        [VehicleClass.Vans] = 'Van',
        [VehicleClass.Cycles] = 'Bicicleta',
        [VehicleClass.Boats] = 'Barco',
        [VehicleClass.Helicopters] = 'Helicóptero',
        [VehicleClass.Planes] = 'Avião',
        [VehicleClass.Service] = 'Serviço',
        [VehicleClass.Emergency] = 'Emergência',
        [VehicleClass.Military] = 'Militar',
        [VehicleClass.Commercial] = 'Comercial',
        [VehicleClass.Trains] = 'Trem',
        [VehicleClass.OpenWheels] = 'Open Wheel',
    }

    return labels[class] or locale('ui.unknown')
end

local function createChoice(id, label, installed, price, apply, successLabel, level)
    return {
        id = id,
        label = label,
        installed = installed,
        duplicate = installed,
        blocked = false,
        price = price,
        apply = apply,
        successLabel = successLabel,
        level = level,
    }
end

local function addOption(category, option)
    category.enabled = true
    category.options[#category.options + 1] = option
end

local function sortOptions(options)
    table.sort(options, function(a, b)
        return a.label < b.label
    end)
end

local function buildModOption(def)
    local vehicle = session.vehicle
    local modCount = GetNumVehicleMods(vehicle, def.id)
    if modCount <= 0 or def.enabled == false then return nil end

    local currentMod = GetVehicleMod(vehicle, def.id)
    local price = actions.getPrice(def.category == 'performance' and def.id or 'cosmetic', math.max(currentMod + 2, 1))
    local choices = {}

    for modIndex = -1, modCount - 1 do
        local choicePrice = actions.getPrice(def.category == 'performance' and def.id or 'cosmetic', modIndex + 2)
        local label = GetModLabel(vehicle, def.id, modIndex)
        choices[#choices + 1] = createChoice(
            ('%s:%s'):format(def.id, modIndex),
            label,
            currentMod == modIndex,
            choicePrice,
            function(targetVehicle)
                SetVehicleMod(targetVehicle, def.id, modIndex, false)
            end,
            locale('menus.general.installed', label),
            modIndex + 2
        )
    end

    return {
        id = ('mod:%s'):format(def.id),
        label = def.label,
        icon = def.icon,
        asset = def.asset,
        group = def.group,
        price = price,
        priceMod = def.category == 'performance' and def.id or 'cosmetic',
        choices = choices,
        disabled = false,
    }
end

local function buildTurboOption()
    local vehicle = session.vehicle
    if GetVehicleClass(vehicle) == VehicleClass.Cycles then return nil end

    local enabled = IsToggleModOn(vehicle, 18)
    local price = actions.getPrice(18)

    return {
        id = 'toggle:turbo',
        label = locale('menus.performance.turbo'),
        icon = '➤',
        asset = 'custom_turbo',
        group = 'Performance',
        price = price,
        priceMod = 18,
        choices = {
            createChoice('turbo:off', locale('menus.general.disabled'), not enabled, price, function(targetVehicle)
                ToggleVehicleMod(targetVehicle, 18, false)
            end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.disabled')), 1),
            createChoice('turbo:on', locale('menus.general.enabled'), enabled, price, function(targetVehicle)
                ToggleVehicleMod(targetVehicle, 18, true)
            end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.enabled')), 2)
        },
        disabled = false,
    }
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

local function buildWheelOptions()
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

            choices[#choices + 1] = createChoice(
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

                choices[#choices + 1] = createChoice(
                    ('wheelrear:%s'):format(index),
                    label,
                    currentRear == index,
                    actions.getPrice('cosmetic'),
                    function(targetVehicle)
                        SetVehicleWheelType(targetVehicle, 6)
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

    sortOptions(options)
    return options
end

local function buildWindowTintOption()
    local current = GetVehicleWindowTint(session.vehicle)
    local choices = {}

    for index, tint in ipairs(config.windowTints) do
        choices[#choices + 1] = createChoice(
            ('window:%s'):format(tint.id),
            tint.label,
            current == tint.id,
            actions.getPrice('cosmetic'),
            function(targetVehicle)
                SetVehicleWindowTint(targetVehicle, tint.id)
            end,
            locale('menus.options.windowTint.installed', tint.label),
            index
        )
    end

    return {
        id = 'window_tint',
        label = locale('menus.options.windowTint.title'),
        icon = '◪',
        asset = 'window',
        group = 'Vidros',
        price = actions.getPrice('cosmetic'),
        priceMod = 'cosmetic',
        choices = choices,
        disabled = false,
    }
end

local function buildPlateIndexOption()
    local current = GetVehicleNumberPlateTextIndex(session.vehicle)
    local choices = {}

    for index, plate in ipairs(config.plateIndexes) do
        choices[#choices + 1] = createChoice(
            ('plateindex:%s'):format(plate.id),
            plate.label,
            current == plate.id,
            actions.getPrice('cosmetic'),
            function(targetVehicle)
                SetVehicleNumberPlateTextIndex(targetVehicle, plate.id)
            end,
            locale('menus.options.plateIndex.installed', plate.label),
            index
        )
    end

    return {
        id = 'plate_index',
        label = locale('menus.options.plateIndex.title'),
        icon = '▣',
        asset = 'plate',
        group = 'Placas',
        price = actions.getPrice('cosmetic'),
        priceMod = 'cosmetic',
        choices = choices,
        disabled = false,
    }
end

local function buildExtrasOptions()
    local options = {}

    for extra = 1, 14 do
        if not DoesExtraExist(session.vehicle, extra) then goto continue end

        local isEnabled = IsVehicleExtraTurnedOn(session.vehicle, extra)
        options[#options + 1] = {
            id = ('extra:%s'):format(extra),
            label = ('Extra %d'):format(extra),
            icon = '⋯',
            asset = 'extra',
            group = 'Extras',
            price = actions.getPrice('cosmetic'),
            priceMod = 'cosmetic',
            choices = {
                createChoice(('extra:%s:on'):format(extra), locale('menus.general.enabled'), isEnabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 0)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.enabled')), 2),
                createChoice(('extra:%s:off'):format(extra), locale('menus.general.disabled'), not isEnabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 1)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.disabled')), 1),
            },
            disabled = false,
        }

        ::continue::
    end

    sortOptions(options)
    return options
end

local function buildNeonOptions()
    local options = {}

    for _, neon in ipairs(config.neon) do
        local enabled = IsVehicleNeonLightEnabled(session.vehicle, neon.id)
        options[#options + 1] = {
            id = ('neon_side:%s'):format(neon.id),
            label = locale('menus.neon.neon', neon.label, ''),
            icon = '✦',
            asset = 'neon',
            group = 'Neon',
            price = actions.getPrice('cosmetic'),
            priceMod = 'cosmetic',
            choices = {
                createChoice(('neon_side:%s:off'):format(neon.id), locale('menus.general.disabled'), not enabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, false)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.disabled')), 1),
                createChoice(('neon_side:%s:on'):format(neon.id), locale('menus.general.enabled'), enabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, true)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.enabled')), 2),
            },
            disabled = false,
        }
    end

    local r, g, b = GetVehicleNeonLightsColour(session.vehicle)
    local colorChoices = {}
    for index, neonColor in ipairs(config.neonColors) do
        colorChoices[#colorChoices + 1] = createChoice(
            ('neon_color:%s'):format(index),
            neonColor.label,
            neonColor.r == r and neonColor.g == g and neonColor.b == b,
            actions.getPrice('cosmetic'),
            function(targetVehicle)
                SetVehicleNeonLightsColour(targetVehicle, neonColor.r, neonColor.g, neonColor.b)
            end,
            locale('menus.neon.installed', neonColor.label),
            index
        )
    end

    options[#options + 1] = {
        id = 'neon_color',
        label = locale('menus.neon.color'),
        icon = '✦',
        asset = 'neon',
        group = 'Neon',
        price = actions.getPrice('cosmetic'),
        priceMod = 'cosmetic',
        choices = colorChoices,
        disabled = false,
    }

    sortOptions(options)
    return options
end

local function buildXenonOption()
    if GetNumVehicleMods(session.vehicle, 22) <= 0 then return nil end

    local toggle = IsToggleModOn(session.vehicle, 22)
    local current = GetVehicleXenonLightsColor(session.vehicle)
    current = current == 255 and -1 or current
    local choices = {
        createChoice('xenon:disabled', locale('menus.general.disabled'), not toggle, actions.getPrice('cosmetic'), function(targetVehicle)
            ToggleVehicleMod(targetVehicle, 22, false)
        end, locale('menus.options.xenon.installed', locale('menus.general.disabled')), 1)
    }

    for index, xenon in ipairs(config.xenon) do
        if xenon.id ~= -1 then
            choices[#choices + 1] = createChoice(
                ('xenon:%s'):format(xenon.id),
                xenon.label,
                toggle and current == xenon.id,
                actions.getPrice('cosmetic'),
                function(targetVehicle)
                    ToggleVehicleMod(targetVehicle, 22, true)
                    SetVehicleXenonLightsColor(targetVehicle, xenon.id)
                end,
                locale('menus.options.xenon.installed', xenon.label),
                index + 1
            )
        end
    end

    return {
        id = 'xenon',
        label = locale('menus.options.xenon.title'),
        icon = '✦',
        asset = 'xenon',
        group = 'Iluminação',
        price = actions.getPrice('cosmetic'),
        priceMod = 'cosmetic',
        choices = choices,
        disabled = false,
    }
end

local function buildLiveryOption()
    local oldLivery = GetVehicleLivery(session.vehicle)
    local newLivery = GetVehicleMod(session.vehicle, 48)
    local choices = {}

    if newLivery >= 0 or oldLivery == -1 then
        local modCount = GetNumVehicleMods(session.vehicle, 48)
        if modCount <= 0 then return nil end

        choices[#choices + 1] = createChoice('livery:stock', locale('menus.general.stock'), newLivery == -1, actions.getPrice('cosmetic'), function(targetVehicle)
            SetVehicleMod(targetVehicle, 48, -1, false)
        end, locale('menus.general.installed', locale('menus.general.stock')), 1)

        for index = 0, modCount - 1 do
            local rawLabel = GetModTextLabel(session.vehicle, 48, index)
            local label = rawLabel and rawLabel ~= '' and GetLabelText(rawLabel) or ('Livery %d'):format(index + 1)
            choices[#choices + 1] = createChoice(
                ('livery:new:%s'):format(index),
                label,
                newLivery == index,
                actions.getPrice('cosmetic'),
                function(targetVehicle)
                    SetVehicleMod(targetVehicle, 48, index, false)
                end,
                locale('menus.general.installed', label),
                index + 2
            )
        end
    else
        local liveryCount = GetVehicleLiveryCount(session.vehicle)
        if liveryCount <= 0 then return nil end

        for index = 0, liveryCount - 1 do
            local label = ('%s %d'):format(locale('menus.options.livery'), index + 1)
            choices[#choices + 1] = createChoice(
                ('livery:old:%s'):format(index),
                label,
                oldLivery == index,
                actions.getPrice('cosmetic'),
                function(targetVehicle)
                    SetVehicleLivery(targetVehicle, index)
                end,
                locale('menus.general.installed', label),
                index + 1
            )
        end
    end

    if #choices == 0 then return nil end

    return {
        id = 'livery',
        label = locale('menus.options.livery'),
        icon = '▨',
        asset = '48',
        group = 'Visual',
        price = actions.getPrice('cosmetic'),
        priceMod = 'cosmetic',
        choices = choices,
        disabled = false,
    }
end

local function buildRepairOption()
    local bodyHealth = GetVehicleBodyHealth(session.vehicle)
    if bodyHealth >= 1000.0 then return nil end

    local price = math.ceil(1000 - bodyHealth)
    return {
        id = 'service:repair',
        label = locale('menus.main.repair'),
        icon = '✚',
        asset = 'custom_engine',
        group = 'Serviços',
        price = price,
        action = 'repair',
        disabled = false,
        choices = {
            {
                id = 'repair:confirm',
                label = locale('ui.repairNow'),
                installed = false,
                duplicate = false,
                blocked = false,
                price = price,
                isAction = true,
                action = 'repair',
            }
        }
    }
end

function catalog.build()
    local runtime = {categories = {}, options = {}, vehicle = {}}
    local categories = {
        service = cloneCategory('service'),
        performance = cloneCategory('performance'),
        body = cloneCategory('body'),
        wheels = cloneCategory('wheels'),
        lights = cloneCategory('lights'),
        plates = cloneCategory('plates'),
        extras = cloneCategory('extras'),
    }

    local repairOption = buildRepairOption()
    if repairOption then addOption(categories.service, repairOption) end

    for _, def in ipairs(config.mods) do
        if def.category == 'performance' and def.id ~= 18 then
            local option = buildModOption(def)
            if option then addOption(categories.performance, option) end
        elseif def.category == 'body' then
            local option = buildModOption(def)
            if option then addOption(categories.body, option) end
        elseif def.category == 'plates' then
            local option = buildModOption(def)
            if option then addOption(categories.plates, option) end
        elseif def.category == 'lights' and def.id ~= 48 then
            local option = buildModOption(def)
            if option then addOption(categories.lights, option) end
        end
    end

    local turboOption = buildTurboOption()
    if turboOption then addOption(categories.performance, turboOption) end

    local wheelOptions = buildWheelOptions()
    for _, option in ipairs(wheelOptions) do addOption(categories.wheels, option) end

    do
        local option = buildPlateIndexOption()
        if option then addOption(categories.plates, option) end
    end

    do
        local option = buildWindowTintOption()
        if option then addOption(categories.lights, option) end
    end

    do
        local option = buildXenonOption()
        if option then addOption(categories.lights, option) end
    end

    for _, option in ipairs(buildNeonOptions()) do addOption(categories.lights, option) end

    local liveryOption = buildLiveryOption()
    if liveryOption then addOption(categories.lights, liveryOption) end

    for _, option in ipairs(buildExtrasOptions()) do addOption(categories.extras, option) end

    for _, categoryDef in ipairs(config.categories) do
        local category = categories[categoryDef.id]
        sortOptions(category.options)
        for _, option in ipairs(category.options) do
            runtime.options[option.id] = option
        end
        runtime.categories[#runtime.categories + 1] = category
    end

    local model = GetEntityModel(session.vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local vehicleName = GetLabelText(displayName)
    if not vehicleName or vehicleName == 'NULL' then
        vehicleName = displayName
    end

    runtime.vehicle = {
        name = vehicleName,
        class = getClassLabel(GetVehicleClass(session.vehicle)),
        plate = GetVehicleNumberPlateText(session.vehicle),
    }

    return runtime
end

return catalog
