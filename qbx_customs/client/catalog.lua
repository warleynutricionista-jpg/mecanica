local session = require 'client.session'
local config = require 'config.client'
local common = require 'client.catalog_builder.common'
local modBuilders = require 'client.catalog_builder.mods'
local wheelBuilders = require 'client.catalog_builder.wheels'
local appearanceBuilders = require 'client.catalog_builder.appearance'

local catalog = {}

local function appendOptions(category, options)
    for _, option in ipairs(options) do
        common.addOption(category, option)
    end
end

function catalog.build()
    local runtime = { categories = {}, options = {}, vehicle = {} }
    local categories = {
        service = common.cloneCategory('service'),
        performance = common.cloneCategory('performance'),
        body = common.cloneCategory('body'),
        wheels = common.cloneCategory('wheels'),
        lights = common.cloneCategory('lights'),
        plates = common.cloneCategory('plates'),
        extras = common.cloneCategory('extras'),
    }

    common.addOption(categories.service, modBuilders.buildRepairOption())
    appendOptions(categories.performance, modBuilders.buildModOptions('performance'))
    appendOptions(categories.body, modBuilders.buildModOptions('body'))
    appendOptions(categories.plates, modBuilders.buildModOptions('plates'))
    appendOptions(categories.lights, modBuilders.buildModOptions('lights'))

    common.addOption(categories.performance, modBuilders.buildTurboOption())
    appendOptions(categories.wheels, wheelBuilders.buildWheelOptions())
    common.addOption(categories.plates, appearanceBuilders.buildPlateIndexOption())
    common.addOption(categories.lights, appearanceBuilders.buildWindowTintOption())
    common.addOption(categories.lights, appearanceBuilders.buildXenonOption())
    appendOptions(categories.lights, appearanceBuilders.buildNeonOptions())
    common.addOption(categories.lights, appearanceBuilders.buildLiveryOption())
    appendOptions(categories.extras, appearanceBuilders.buildExtrasOptions())

    for _, categoryDef in ipairs(config.categories) do
        local category = categories[categoryDef.id]
        common.sortOptions(category.options)

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
        class = common.getClassLabel(GetVehicleClass(session.vehicle)),
        plate = GetVehicleNumberPlateText(session.vehicle),
    }

    return runtime
end

return catalog
