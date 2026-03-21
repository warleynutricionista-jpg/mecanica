local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

local function getPriceKey(definition)
    return definition.category == 'performance' and definition.id or 'cosmetic'
end

local function buildChoicesForMod(definition, currentMod, modCount)
    local choices = {}
    local priceKey = getPriceKey(definition)

    for modIndex = -1, modCount - 1 do
        local label = GetModLabel(session.vehicle, definition.id, modIndex)
        choices[#choices + 1] = common.createChoice(
            ('%s:%s'):format(definition.id, modIndex),
            label,
            currentMod == modIndex,
            actions.getPrice(priceKey, modIndex + 2),
            function(targetVehicle)
                SetVehicleMod(targetVehicle, definition.id, modIndex, false)
            end,
            locale('menus.general.installed', label),
            modIndex + 2
        )
    end

    return choices, priceKey
end

local function isModDefinitionEnabled(definition, categoryId)
    if definition.category ~= categoryId then
        return false
    end

    if definition.enabled == false then
        return false
    end

    if categoryId == 'performance' and definition.id == 18 then
        return false
    end

    if categoryId == 'lights' and definition.id == 48 then
        return false
    end

    return true
end

function builders.buildModOptions(categoryId)
    local options = {}
    local vehicle = session.vehicle

    for _, definition in ipairs(config.mods) do
        if not isModDefinitionEnabled(definition, categoryId) then goto continue end

        local modCount = GetNumVehicleMods(vehicle, definition.id)
        if modCount <= 0 then goto continue end

        local currentMod = GetVehicleMod(vehicle, definition.id)
        local choices, priceKey = buildChoicesForMod(definition, currentMod, modCount)
        options[#options + 1] = common.createOption(
            ('mod:%s'):format(definition.id),
            definition.label,
            definition.icon,
            definition.asset,
            definition.group,
            actions.getPrice(priceKey, math.max(currentMod + 2, 1)),
            priceKey,
            choices
        )

        ::continue::
    end

    return options
end

function builders.buildTurboOption()
    local vehicle = session.vehicle
    if GetVehicleClass(vehicle) == 13 then return nil end

    local enabled = IsToggleModOn(vehicle, 18)
    local price = actions.getPrice(18)

    return common.createOption('toggle:turbo', locale('menus.performance.turbo'), '➤', 'custom_turbo', 'Performance', price, 18, {
        common.createChoice('turbo:off', locale('menus.general.disabled'), not enabled, price, function(targetVehicle)
            ToggleVehicleMod(targetVehicle, 18, false)
        end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.disabled')), 1),
        common.createChoice('turbo:on', locale('menus.general.enabled'), enabled, price, function(targetVehicle)
            ToggleVehicleMod(targetVehicle, 18, true)
        end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.enabled')), 2)
    })
end

function builders.buildRepairOption()
    local bodyHealth = GetVehicleBodyHealth(session.vehicle)
    if bodyHealth >= 1000.0 then return nil end

    local price = math.max(0, math.ceil(1000 - bodyHealth))
    return common.createOption('service:repair', locale('menus.main.repair'), '✚', 'custom_engine', 'Serviços', price, 'repair', {
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
    }, {
        action = 'repair',
    })
end

return builders
