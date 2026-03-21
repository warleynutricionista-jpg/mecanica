local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

function builders.buildWindowTintOption()
    local current = GetVehicleWindowTint(session.vehicle)
    local choices = {}

    for index, tint in ipairs(config.windowTints) do
        choices[#choices + 1] = common.createChoice(
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

function builders.buildPlateIndexOption()
    local current = GetVehicleNumberPlateTextIndex(session.vehicle)
    local choices = {}

    for index, plate in ipairs(config.plateIndexes) do
        choices[#choices + 1] = common.createChoice(
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

function builders.buildExtrasOptions()
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
                common.createChoice(('extra:%s:on'):format(extra), locale('menus.general.enabled'), isEnabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 0)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.enabled')), 2),
                common.createChoice(('extra:%s:off'):format(extra), locale('menus.general.disabled'), not isEnabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 1)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.disabled')), 1),
            },
            disabled = false,
        }

        ::continue::
    end

    common.sortOptions(options)
    return options
end

function builders.buildNeonOptions()
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
                common.createChoice(('neon_side:%s:off'):format(neon.id), locale('menus.general.disabled'), not enabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, false)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.disabled')), 1),
                common.createChoice(('neon_side:%s:on'):format(neon.id), locale('menus.general.enabled'), enabled, actions.getPrice('cosmetic'), function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, true)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.enabled')), 2),
            },
            disabled = false,
        }
    end

    local r, g, b = GetVehicleNeonLightsColour(session.vehicle)
    local colorChoices = {}
    for index, neonColor in ipairs(config.neonColors) do
        colorChoices[#colorChoices + 1] = common.createChoice(
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

    common.sortOptions(options)
    return options
end

function builders.buildXenonOption()
    if GetNumVehicleMods(session.vehicle, 22) <= 0 then return nil end

    local toggle = IsToggleModOn(session.vehicle, 22)
    local current = GetVehicleXenonLightsColor(session.vehicle)
    current = current == 255 and -1 or current
    local choices = {
        common.createChoice('xenon:disabled', locale('menus.general.disabled'), not toggle, actions.getPrice('cosmetic'), function(targetVehicle)
            ToggleVehicleMod(targetVehicle, 22, false)
        end, locale('menus.options.xenon.installed', locale('menus.general.disabled')), 1)
    }

    for index, xenon in ipairs(config.xenon) do
        if xenon.id ~= -1 then
            choices[#choices + 1] = common.createChoice(
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

function builders.buildLiveryOption()
    local oldLivery = GetVehicleLivery(session.vehicle)
    local newLivery = GetVehicleMod(session.vehicle, 48)
    local choices = {}

    if newLivery >= 0 or oldLivery == -1 then
        local modCount = GetNumVehicleMods(session.vehicle, 48)
        if modCount <= 0 then return nil end

        choices[#choices + 1] = common.createChoice('livery:stock', locale('menus.general.stock'), newLivery == -1, actions.getPrice('cosmetic'), function(targetVehicle)
            SetVehicleMod(targetVehicle, 48, -1, false)
        end, locale('menus.general.installed', locale('menus.general.stock')), 1)

        for index = 0, modCount - 1 do
            local rawLabel = GetModTextLabel(session.vehicle, 48, index)
            local label = rawLabel and rawLabel ~= '' and GetLabelText(rawLabel) or ('Livery %d'):format(index + 1)
            choices[#choices + 1] = common.createChoice(
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
            choices[#choices + 1] = common.createChoice(
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

return builders
