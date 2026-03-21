local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

local function cosmeticPrice()
    return actions.getPrice('cosmetic')
end

local function buildSimpleChoices(items, currentId, idPrefix, applyCallback, successLocalePath)
    local price = cosmeticPrice()
    local choices = {}

    for index, item in ipairs(items) do
        choices[#choices + 1] = common.createChoice(
            ('%s:%s'):format(idPrefix, item.id),
            item.label,
            currentId == item.id,
            price,
            function(targetVehicle)
                applyCallback(targetVehicle, item)
            end,
            locale(successLocalePath, item.label),
            index
        )
    end

    return choices
end

function builders.buildWindowTintOption()
    local current = GetVehicleWindowTint(session.vehicle)
    return common.createOption(
        'window_tint',
        locale('menus.options.windowTint.title'),
        '◪',
        'window',
        'Vidros',
        cosmeticPrice(),
        'cosmetic',
        buildSimpleChoices(config.windowTints, current, 'window', function(targetVehicle, tint)
            SetVehicleWindowTint(targetVehicle, tint.id)
        end, 'menus.options.windowTint.installed')
    )
end

function builders.buildPlateIndexOption()
    local current = GetVehicleNumberPlateTextIndex(session.vehicle)
    return common.createOption(
        'plate_index',
        locale('menus.options.plateIndex.title'),
        '▣',
        'plate',
        'Placas',
        cosmeticPrice(),
        'cosmetic',
        buildSimpleChoices(config.plateIndexes, current, 'plateindex', function(targetVehicle, plate)
            SetVehicleNumberPlateTextIndex(targetVehicle, plate.id)
        end, 'menus.options.plateIndex.installed')
    )
end

function builders.buildExtrasOptions()
    local options = {}
    local price = cosmeticPrice()

    for extra = 1, 14 do
        if not DoesExtraExist(session.vehicle, extra) then goto continue end

        local isEnabled = IsVehicleExtraTurnedOn(session.vehicle, extra)
        options[#options + 1] = common.createOption(
            ('extra:%s'):format(extra),
            ('Extra %d'):format(extra),
            '⋯',
            'extra',
            'Extras',
            price,
            'cosmetic',
            {
                common.createChoice(('extra:%s:on'):format(extra), locale('menus.general.enabled'), isEnabled, price, function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 0)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.enabled')), 2),
                common.createChoice(('extra:%s:off'):format(extra), locale('menus.general.disabled'), not isEnabled, price, function(targetVehicle)
                    SetVehicleExtra(targetVehicle, extra, 1)
                end, locale('menus.performance.toggleState', ('Extra %d'):format(extra), locale('menus.general.disabled')), 1),
            }
        )

        ::continue::
    end

    common.sortOptions(options)
    return options
end

function builders.buildNeonOptions()
    local options = {}
    local price = cosmeticPrice()

    for _, neon in ipairs(config.neon) do
        local enabled = IsVehicleNeonLightEnabled(session.vehicle, neon.id)
        options[#options + 1] = common.createOption(
            ('neon_side:%s'):format(neon.id),
            locale('menus.neon.neon', neon.label, ''),
            '✦',
            'neon',
            'Neon',
            price,
            'cosmetic',
            {
                common.createChoice(('neon_side:%s:off'):format(neon.id), locale('menus.general.disabled'), not enabled, price, function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, false)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.disabled')), 1),
                common.createChoice(('neon_side:%s:on'):format(neon.id), locale('menus.general.enabled'), enabled, price, function(targetVehicle)
                    SetVehicleNeonLightEnabled(targetVehicle, neon.id, true)
                end, locale('menus.performance.toggleState', neon.label, locale('menus.general.enabled')), 2),
            }
        )
    end

    local r, g, b = GetVehicleNeonLightsColour(session.vehicle)
    local colorChoices = {}
    for index, neonColor in ipairs(config.neonColors) do
        colorChoices[#colorChoices + 1] = common.createChoice(
            ('neon_color:%s'):format(index),
            neonColor.label,
            neonColor.r == r and neonColor.g == g and neonColor.b == b,
            price,
            function(targetVehicle)
                SetVehicleNeonLightsColour(targetVehicle, neonColor.r, neonColor.g, neonColor.b)
            end,
            locale('menus.neon.installed', neonColor.label),
            index
        )
    end

    options[#options + 1] = common.createOption('neon_color', locale('menus.neon.color'), '✦', 'neon', 'Neon', price, 'cosmetic', colorChoices)
    common.sortOptions(options)
    return options
end

function builders.buildXenonOption()
    if GetNumVehicleMods(session.vehicle, 22) <= 0 then return nil end

    local price = cosmeticPrice()
    local toggle = IsToggleModOn(session.vehicle, 22)
    local current = GetVehicleXenonLightsColor(session.vehicle)
    current = current == 255 and -1 or current
    local choices = {
        common.createChoice('xenon:disabled', locale('menus.general.disabled'), not toggle, price, function(targetVehicle)
            ToggleVehicleMod(targetVehicle, 22, false)
        end, locale('menus.options.xenon.installed', locale('menus.general.disabled')), 1)
    }

    for index, xenon in ipairs(config.xenon) do
        if xenon.id ~= -1 then
            choices[#choices + 1] = common.createChoice(
                ('xenon:%s'):format(xenon.id),
                xenon.label,
                toggle and current == xenon.id,
                price,
                function(targetVehicle)
                    ToggleVehicleMod(targetVehicle, 22, true)
                    SetVehicleXenonLightsColor(targetVehicle, xenon.id)
                end,
                locale('menus.options.xenon.installed', xenon.label),
                index + 1
            )
        end
    end

    return common.createOption('xenon', locale('menus.options.xenon.title'), '✦', 'xenon', 'Iluminação', price, 'cosmetic', choices)
end

function builders.buildLiveryOption()
    local oldLivery = GetVehicleLivery(session.vehicle)
    local newLivery = GetVehicleMod(session.vehicle, 48)
    local choices = {}
    local price = cosmeticPrice()

    if newLivery >= 0 or oldLivery == -1 then
        local modCount = GetNumVehicleMods(session.vehicle, 48)
        if modCount <= 0 then return nil end

        choices[#choices + 1] = common.createChoice('livery:stock', locale('menus.general.stock'), newLivery == -1, price, function(targetVehicle)
            SetVehicleMod(targetVehicle, 48, -1, false)
        end, locale('menus.general.installed', locale('menus.general.stock')), 1)

        for index = 0, modCount - 1 do
            local rawLabel = GetModTextLabel(session.vehicle, 48, index)
            local label = rawLabel and rawLabel ~= '' and GetLabelText(rawLabel) or ('Livery %d'):format(index + 1)
            if label == 'NULL' then
                label = ('Livery %d'):format(index + 1)
            end

            choices[#choices + 1] = common.createChoice(
                ('livery:new:%s'):format(index),
                label,
                newLivery == index,
                price,
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
                price,
                function(targetVehicle)
                    SetVehicleLivery(targetVehicle, index)
                end,
                locale('menus.general.installed', label),
                index + 1
            )
        end
    end

    if #choices == 0 then return nil end

    return common.createOption('livery', locale('menus.options.livery'), '▨', '48', 'Visual', price, 'cosmetic', choices)
end

return builders
