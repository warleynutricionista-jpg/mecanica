local clientConfig = require 'config.client'
local pricing = require 'shared.pricing'
local session = require 'client.session'
local vehicleService = require 'client.services.vehicle'

local catalog = {}

local wheelTypeCycle = 13
local wheelTypeMotorcycle = 8
local wheelTypeOpenWheel = 22

local function getLabelFromGame(rawLabel, fallback)
    if not rawLabel or rawLabel == '' then
        return fallback
    end

    local translated = GetLabelText(rawLabel)
    if translated and translated ~= 'NULL' then
        return translated
    end

    return fallback
end

local function resolveVehicleName(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(displayName)
    if label and label ~= 'NULL' then
        return label
    end

    return displayName
end

local function getClassLabel(vehicle)
    return clientConfig.vehicleClasses[GetVehicleClass(vehicle)] or locale('ui.unknown')
end

local function resolveModLabel(vehicle, modType, modIndex)
    local customSet = clientConfig.modLabels[modType]
    if customSet and customSet[modIndex] then
        return customSet[modIndex]
    end

    if modIndex == -1 then
        return locale('menus.general.stock')
    end

    local fallback = ('%s %d'):format(locale('menus.general.variant'), modIndex + 1)
    return getLabelFromGame(GetModTextLabel(vehicle, modType, modIndex), fallback)
end

local function makeChoice(data)
    return {
        id = data.id,
        label = data.label,
        price = data.price,
        priceKey = data.priceKey,
        priceLevel = data.priceLevel,
        installed = data.installed == true,
        blocked = data.blocked == true,
        isAction = data.isAction == true,
        preview = data.preview,
        serviceType = data.serviceType or 'mod',
        metadata = data.metadata,
    }
end

local function makeOption(data)
    return {
        id = data.id,
        category = data.category,
        label = data.label,
        group = data.group,
        icon = data.icon,
        disabled = data.disabled == true,
        choices = data.choices or {},
    }
end

local function addOption(categories, option)
    if not option or option.disabled then
        return
    end

    local category = categories[option.category]
    if not category then
        return
    end

    category.options[#category.options + 1] = option
end

local function buildRepairOption(vehicle, categories)
    local price = pricing.get('repair', nil, { bodyHealth = GetVehicleBodyHealth(vehicle) })
    if price <= 0 then
        return
    end

    addOption(categories, makeOption({
        id = 'service:repair',
        category = 'service',
        label = locale('menus.main.repair'),
        group = locale('menus.main.repairGroup'),
        icon = 'screwdriver-wrench',
        choices = {
            makeChoice({
                id = 'repair:full',
                label = locale('ui.repairNow'),
                price = price,
                priceKey = 'repair',
                priceLevel = 1,
                serviceType = 'repair',
                isAction = true,
                preview = function()
                    return vehicleService.applyRepairPreview()
                end,
            }),
        },
    }))
end

local function buildRegularMods(vehicle, categories)
    for i = 1, #clientConfig.mods do
        local mod = clientConfig.mods[i]
        if mod.id ~= 18 and mod.id ~= 48 then
            local modCount = GetNumVehicleMods(vehicle, mod.id)
            if modCount > 0 then
                local current = GetVehicleMod(vehicle, mod.id)
                local priceKey = mod.category == 'performance' and mod.id or 'cosmetic'
                local choices = {}

                for index = -1, modCount - 1 do
                    local label = resolveModLabel(vehicle, mod.id, index)
                    choices[#choices + 1] = makeChoice({
                        id = ('%s:%s'):format(mod.id, index),
                        label = label,
                        price = pricing.get(priceKey, index + 2),
                        priceKey = priceKey,
                        priceLevel = index + 2,
                        installed = current == index,
                        preview = function()
                            SetVehicleMod(vehicle, mod.id, index, false)
                        end,
                    })
                end

                addOption(categories, makeOption({
                    id = ('mod:%s'):format(mod.id),
                    category = mod.category,
                    label = mod.label,
                    group = mod.group,
                    icon = mod.icon,
                    choices = choices,
                }))
            end
        end
    end
end

local function buildTurbo(vehicle, categories)
    if GetVehicleClass(vehicle) == 13 then
        return
    end

    local enabled = IsToggleModOn(vehicle, 18)
    addOption(categories, makeOption({
        id = 'toggle:turbo',
        category = 'performance',
        label = locale('menus.performance.turbo'),
        group = locale('menus.performance.title'),
        icon = 'gauge-high',
        choices = {
            makeChoice({
                id = 'turbo:off',
                label = locale('menus.general.disabled'),
                price = pricing.get(18, 1),
                priceKey = 18,
                priceLevel = 1,
                installed = not enabled,
                preview = function()
                    ToggleVehicleMod(vehicle, 18, false)
                end,
            }),
            makeChoice({
                id = 'turbo:on',
                label = locale('menus.general.enabled'),
                price = pricing.get(18, 2),
                priceKey = 18,
                priceLevel = 2,
                installed = enabled,
                preview = function()
                    ToggleVehicleMod(vehicle, 18, true)
                end,
            }),
        },
    }))
end

local function buildWheelOptions(vehicle, categories)
    local vehicleClass = GetVehicleClass(vehicle)
    if vehicleClass == wheelTypeCycle then
        return
    end

    local originalWheelType = GetVehicleWheelType(vehicle)
    local currentFront = GetVehicleMod(vehicle, 23)
    local currentRear = GetVehicleMod(vehicle, 24)

    for i = 1, #clientConfig.wheels do
        local wheelType = clientConfig.wheels[i]
        local allowed = true

        if vehicleClass == wheelTypeMotorcycle then
            allowed = wheelType.id == 6
        elseif vehicleClass == wheelTypeOpenWheel then
            allowed = wheelType.id == 10
        end

        if allowed then
            SetVehicleWheelType(vehicle, wheelType.id)
            local count = GetNumVehicleMods(vehicle, 23)
            if count > 0 then
                local choices = {}
                for index = 0, count - 1 do
                    local fallback = ('%s %d'):format(wheelType.label, index + 1)
                    choices[#choices + 1] = makeChoice({
                        id = ('wheel:%s:%s'):format(wheelType.id, index),
                        label = getLabelFromGame(GetModTextLabel(vehicle, 23, index), fallback),
                        price = pricing.get('cosmetic', 1),
                        priceKey = 'cosmetic',
                        priceLevel = 1,
                        installed = originalWheelType == wheelType.id and currentFront == index,
                        preview = function()
                            SetVehicleWheelType(vehicle, wheelType.id)
                            SetVehicleMod(vehicle, 23, index, false)
                            if vehicleClass ~= wheelTypeMotorcycle then
                                SetVehicleMod(vehicle, 24, -1, false)
                            end
                        end,
                    })
                end

                addOption(categories, makeOption({
                    id = ('wheelcat:%s'):format(wheelType.id),
                    category = 'wheels',
                    label = wheelType.label,
                    group = locale('menus.wheels.title'),
                    icon = 'compact-disc',
                    choices = choices,
                }))
            end
        end
    end

    SetVehicleWheelType(vehicle, originalWheelType)
    SetVehicleMod(vehicle, 23, currentFront, false)
    SetVehicleMod(vehicle, 24, currentRear, false)

    if vehicleClass == wheelTypeMotorcycle then
        local rearCount = GetNumVehicleMods(vehicle, 24)
        if rearCount > 0 then
            local rearChoices = {}
            for index = 0, rearCount - 1 do
                rearChoices[#rearChoices + 1] = makeChoice({
                    id = ('wheelrear:%s'):format(index),
                    label = getLabelFromGame(GetModTextLabel(vehicle, 24, index), ('%s %d'):format(locale('menus.wheels.bikeRear'), index + 1)),
                    price = pricing.get('cosmetic', 1),
                    priceKey = 'cosmetic',
                    priceLevel = 1,
                    installed = currentRear == index,
                    preview = function()
                        SetVehicleWheelType(vehicle, 6)
                        SetVehicleMod(vehicle, 24, index, false)
                    end,
                })
            end

            addOption(categories, makeOption({
                id = 'wheelcat:rear',
                category = 'wheels',
                label = locale('menus.wheels.bikeRear'),
                group = locale('menus.wheels.title'),
                icon = 'compact-disc',
                choices = rearChoices,
            }))
        end
    end
end

local function buildWindowTint(vehicle, categories)
    local current = GetVehicleWindowTint(vehicle)
    local choices = {}
    for i = 1, #clientConfig.windowTints do
        local tint = clientConfig.windowTints[i]
        choices[#choices + 1] = makeChoice({
            id = ('window:%s'):format(tint.id),
            label = tint.label,
            price = pricing.get('cosmetic', 1),
            priceKey = 'cosmetic',
            priceLevel = 1,
            installed = current == tint.id,
            preview = function()
                SetVehicleWindowTint(vehicle, tint.id)
            end,
        })
    end

    addOption(categories, makeOption({
        id = 'window_tint',
        category = 'lights',
        label = locale('menus.options.windowTint.title'),
        group = locale('menus.options.windowTint.group'),
        icon = 'sun',
        choices = choices,
    }))
end

local function buildPlateIndex(vehicle, categories)
    local current = GetVehicleNumberPlateTextIndex(vehicle)
    local choices = {}
    for i = 1, #clientConfig.plateIndexes do
        local item = clientConfig.plateIndexes[i]
        choices[#choices + 1] = makeChoice({
            id = ('plateindex:%s'):format(item.id),
            label = item.label,
            price = pricing.get('cosmetic', 1),
            priceKey = 'cosmetic',
            priceLevel = 1,
            installed = current == item.id,
            preview = function()
                SetVehicleNumberPlateTextIndex(vehicle, item.id)
            end,
        })
    end

    addOption(categories, makeOption({
        id = 'plate_index',
        category = 'plates',
        label = locale('menus.options.plateIndex.title'),
        group = locale('menus.options.plateIndex.group'),
        icon = 'id-card',
        choices = choices,
    }))
end

local function buildXenon(vehicle, categories)
    if GetNumVehicleMods(vehicle, 22) <= 0 then
        return
    end

    local enabled = IsToggleModOn(vehicle, 22)
    local current = GetVehicleXenonLightsColor(vehicle)
    current = current == 255 and -1 or current
    local choices = {
        makeChoice({
            id = 'xenon:disabled',
            label = locale('menus.general.disabled'),
            price = pricing.get('cosmetic', 1),
            priceKey = 'cosmetic',
            priceLevel = 1,
            installed = not enabled,
            preview = function()
                ToggleVehicleMod(vehicle, 22, false)
            end,
        }),
    }

    for i = 1, #clientConfig.xenon do
        local xenon = clientConfig.xenon[i]
        if xenon.id ~= -1 then
            choices[#choices + 1] = makeChoice({
                id = ('xenon:%s'):format(xenon.id),
                label = xenon.label,
                price = pricing.get('cosmetic', 1),
                priceKey = 'cosmetic',
                priceLevel = 1,
                installed = enabled and current == xenon.id,
                preview = function()
                    ToggleVehicleMod(vehicle, 22, true)
                    SetVehicleXenonLightsColor(vehicle, xenon.id)
                end,
            })
        end
    end

    addOption(categories, makeOption({
        id = 'xenon',
        category = 'lights',
        label = locale('menus.options.xenon.title'),
        group = locale('menus.options.xenon.group'),
        icon = 'lightbulb',
        choices = choices,
    }))
end

local function buildNeon(vehicle, categories)
    for i = 1, #clientConfig.neon do
        local side = clientConfig.neon[i]
        local enabled = IsVehicleNeonLightEnabled(vehicle, side.id)
        addOption(categories, makeOption({
            id = ('neon_side:%s'):format(side.id),
            category = 'lights',
            label = locale('menus.neon.side', side.label),
            group = locale('menus.neon.title'),
            icon = 'lightbulb',
            choices = {
                makeChoice({
                    id = ('neon_side:%s:off'):format(side.id),
                    label = locale('menus.general.disabled'),
                    price = pricing.get('cosmetic', 1),
                    priceKey = 'cosmetic',
                    priceLevel = 1,
                    installed = not enabled,
                    preview = function()
                        SetVehicleNeonLightEnabled(vehicle, side.id, false)
                    end,
                }),
                makeChoice({
                    id = ('neon_side:%s:on'):format(side.id),
                    label = locale('menus.general.enabled'),
                    price = pricing.get('cosmetic', 1),
                    priceKey = 'cosmetic',
                    priceLevel = 1,
                    installed = enabled,
                    preview = function()
                        SetVehicleNeonLightEnabled(vehicle, side.id, true)
                    end,
                }),
            },
        }))
    end

    local r, g, b = GetVehicleNeonLightsColour(vehicle)
    local colorChoices = {}
    for i = 1, #clientConfig.neonColors do
        local color = clientConfig.neonColors[i]
        colorChoices[#colorChoices + 1] = makeChoice({
            id = ('neon_color:%s'):format(i),
            label = color.label,
            price = pricing.get('cosmetic', 1),
            priceKey = 'cosmetic',
            priceLevel = 1,
            installed = color.r == r and color.g == g and color.b == b,
            preview = function()
                SetVehicleNeonLightsColour(vehicle, color.r, color.g, color.b)
            end,
        })
    end

    addOption(categories, makeOption({
        id = 'neon_color',
        category = 'lights',
        label = locale('menus.neon.color'),
        group = locale('menus.neon.title'),
        icon = 'palette',
        choices = colorChoices,
    }))
end

local function buildLivery(vehicle, categories)
    local currentLivery = GetVehicleLivery(vehicle)
    local currentModLivery = GetVehicleMod(vehicle, 48)
    local choices = {}
    local price = pricing.get('cosmetic', 1)

    if currentModLivery >= 0 or currentLivery == -1 then
        local modCount = GetNumVehicleMods(vehicle, 48)
        if modCount > 0 then
            choices[#choices + 1] = makeChoice({
                id = 'livery:stock',
                label = locale('menus.general.stock'),
                price = price,
                priceKey = 'cosmetic',
                priceLevel = 1,
                installed = currentModLivery == -1,
                preview = function()
                    SetVehicleMod(vehicle, 48, -1, false)
                end,
            })

            for index = 0, modCount - 1 do
                choices[#choices + 1] = makeChoice({
                    id = ('livery:new:%s'):format(index),
                    label = getLabelFromGame(GetModTextLabel(vehicle, 48, index), ('Livery %d'):format(index + 1)),
                    price = price,
                    priceKey = 'cosmetic',
                    priceLevel = 1,
                    installed = currentModLivery == index,
                    preview = function()
                        SetVehicleMod(vehicle, 48, index, false)
                    end,
                })
            end
        end
    else
        local liveryCount = GetVehicleLiveryCount(vehicle)
        if liveryCount > 0 then
            for index = 0, liveryCount - 1 do
                choices[#choices + 1] = makeChoice({
                    id = ('livery:legacy:%s'):format(index),
                    label = ('%s %d'):format(locale('menus.options.livery'), index + 1),
                    price = price,
                    priceKey = 'cosmetic',
                    priceLevel = 1,
                    installed = currentLivery == index,
                    preview = function()
                        SetVehicleLivery(vehicle, index)
                    end,
                })
            end
        end
    end

    if #choices > 0 then
        addOption(categories, makeOption({
            id = 'livery',
            category = 'lights',
            label = locale('menus.options.livery'),
            group = locale('menus.options.liveryGroup'),
            icon = 'paint-roller',
            choices = choices,
        }))
    end
end

local function buildExtras(vehicle, categories)
    for extra = 1, 20 do
        if DoesExtraExist(vehicle, extra) then
            local enabled = IsVehicleExtraTurnedOn(vehicle, extra)
            addOption(categories, makeOption({
                id = ('extra:%s'):format(extra),
                category = 'extras',
                label = ('Extra %d'):format(extra),
                group = locale('menus.extras.title'),
                icon = 'toggle-on',
                choices = {
                    makeChoice({
                        id = ('extra:%s:on'):format(extra),
                        label = locale('menus.general.enabled'),
                        price = pricing.get('cosmetic', 1),
                        priceKey = 'cosmetic',
                        priceLevel = 1,
                        installed = enabled,
                        preview = function()
                            SetVehicleExtra(vehicle, extra, 0)
                        end,
                    }),
                    makeChoice({
                        id = ('extra:%s:off'):format(extra),
                        label = locale('menus.general.disabled'),
                        price = pricing.get('cosmetic', 1),
                        priceKey = 'cosmetic',
                        priceLevel = 1,
                        installed = not enabled,
                        preview = function()
                            SetVehicleExtra(vehicle, extra, 1)
                        end,
                    }),
                },
            }))
        end
    end
end

function catalog.build()
    local vehicle = session.vehicle
    local categoryMap = {}
    local categories = {}

    for i = 1, #clientConfig.categories do
        local category = clientConfig.categories[i]
        categoryMap[category.id] = {
            id = category.id,
            label = category.label,
            icon = category.icon,
            description = category.description,
            options = {},
        }
        categories[#categories + 1] = categoryMap[category.id]
    end

    buildRepairOption(vehicle, categoryMap)
    buildRegularMods(vehicle, categoryMap)
    buildTurbo(vehicle, categoryMap)
    buildWheelOptions(vehicle, categoryMap)
    buildPlateIndex(vehicle, categoryMap)
    buildWindowTint(vehicle, categoryMap)
    buildXenon(vehicle, categoryMap)
    buildNeon(vehicle, categoryMap)
    buildLivery(vehicle, categoryMap)
    buildExtras(vehicle, categoryMap)

    for i = 1, #categories do
        table.sort(categories[i].options, function(a, b)
            return a.label < b.label
        end)
    end

    return {
        categories = categories,
        vehicle = {
            name = resolveVehicleName(vehicle),
            class = getClassLabel(vehicle),
            plate = vehicleService.getPlate(vehicle),
        },
    }
end

return catalog
