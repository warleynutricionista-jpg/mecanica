local config = require 'config.client'
local constants = require 'client.constants'

local common = {}

local categoriesIndex = {}
for _, category in ipairs(config.categories) do
    categoriesIndex[category.id] = category
end

function common.cloneCategory(categoryId)
    local data = categoriesIndex[categoryId]
    if not data then
        return nil
    end

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

function common.addOption(category, option)
    if not category or not option then return end
    category.enabled = true
    category.options[#category.options + 1] = option
end

function common.sortOptions(options)
    table.sort(options, function(a, b)
        return a.label < b.label
    end)
end

function common.createChoice(id, label, installed, price, apply, successLabel, level)
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

function common.createOption(id, label, icon, asset, group, price, priceMod, choices, extra)
    return {
        id = id,
        label = label,
        icon = icon,
        asset = asset,
        group = group,
        price = price,
        priceMod = priceMod,
        choices = choices,
        disabled = false,
        action = extra and extra.action or nil,
    }
end

function common.getClassLabel(class)
    return constants.vehicleClassLabels[class] or locale('ui.unknown')
end

return common
