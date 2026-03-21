local session = require 'client.session'
local actions = require 'client.actions'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'

local builders = {}

function builders.buildModOptions(categoryId)
    local options = {}
    local vehicle = session.vehicle

    for _, def in ipairs(config.mods) do
        if def.category ~= categoryId then goto continue end
        if categoryId == 'performance' and def.id == 18 then goto continue end
        if categoryId == 'lights' and def.id == 48 then goto continue end
        if def.enabled == false then goto continue end

        local modCount = GetNumVehicleMods(vehicle, def.id)
        if modCount <= 0 then goto continue end

        local currentMod = GetVehicleMod(vehicle, def.id)
        local priceKey = def.category == 'performance' and def.id or 'cosmetic'
        local choices = {}

        for modIndex = -1, modCount - 1 do
            local label = GetModLabel(vehicle, def.id, modIndex)
            choices[#choices + 1] = common.createChoice(
                ('%s:%s'):format(def.id, modIndex),
                label,
                currentMod == modIndex,
                actions.getPrice(priceKey, modIndex + 2),
                function(targetVehicle)
                    SetVehicleMod(targetVehicle, def.id, modIndex, false)
                end,
                locale('menus.general.installed', label),
                modIndex + 2
            )
        end

        options[#options + 1] = {
            id = ('mod:%s'):format(def.id),
            label = def.label,
            icon = def.icon,
            asset = def.asset,
            group = def.group,
            price = actions.getPrice(priceKey, math.max(currentMod + 2, 1)),
            priceMod = priceKey,
            choices = choices,
            disabled = false,
        }

        ::continue::
    end

    return options
end

function builders.buildTurboOption()
    local vehicle = session.vehicle
    if GetVehicleClass(vehicle) == 13 then return nil end

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
            common.createChoice('turbo:off', locale('menus.general.disabled'), not enabled, price, function(targetVehicle)
                ToggleVehicleMod(targetVehicle, 18, false)
            end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.disabled')), 1),
            common.createChoice('turbo:on', locale('menus.general.enabled'), enabled, price, function(targetVehicle)
                ToggleVehicleMod(targetVehicle, 18, true)
            end, locale('menus.performance.toggleState', locale('menus.performance.turbo'), locale('menus.general.enabled')), 2)
        },
        disabled = false,
    }
end

function builders.buildRepairOption()
    local bodyHealth = GetVehicleBodyHealth(session.vehicle)
    if bodyHealth >= 1000.0 then return nil end

    local price = math.max(0, math.ceil(1000 - bodyHealth))
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

return builders
