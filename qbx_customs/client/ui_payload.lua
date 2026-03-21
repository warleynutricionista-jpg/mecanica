local session = require 'client.session'
local catalog = require 'client.catalog'
local config = require 'config.client'

local payload = {}

local function summarizeChoice(choice)
    return {
        id = choice.id,
        label = choice.label,
        asset = choice.asset,
        installed = choice.installed,
        blocked = choice.blocked,
        price = choice.price,
        isAction = choice.isAction,
        action = choice.action,
    }
end

local function getFirstEnabledCategory(runtimeCatalog)
    for i = 1, #runtimeCatalog.categories do
        local category = runtimeCatalog.categories[i]
        if category.enabled then
            return category
        end
    end

    return runtimeCatalog.categories[1]
end

local function ensureSelection(runtimeCatalog)
    local currentCategory
    local currentOption

    for i = 1, #runtimeCatalog.categories do
        local category = runtimeCatalog.categories[i]
        if category.id == session.selectedCategory then
            currentCategory = category
            break
        end
    end

    if not currentCategory or not currentCategory.enabled then
        currentCategory = getFirstEnabledCategory(runtimeCatalog)
        session.selectedCategory = currentCategory and currentCategory.id or nil
    end

    if currentCategory then
        currentOption = session.selectedOption and runtimeCatalog.options[session.selectedOption] or nil
        if not currentOption then
            currentOption = currentCategory.options[1] or nil
            session.selectedOption = currentOption and currentOption.id or nil
        end
    else
        session.selectedOption = nil
    end

    if currentOption then
        local resolvedChoiceId = nil

        for i = 1, #currentOption.choices do
            local choice = currentOption.choices[i]
            if choice.id == session.selectedChoice then
                resolvedChoiceId = choice.id
                break
            end

            if not resolvedChoiceId and choice.installed then
                resolvedChoiceId = choice.id
            end
        end

        if not resolvedChoiceId and currentOption.choices[1] then
            resolvedChoiceId = currentOption.choices[1].id
        end

        session.selectedChoice = resolvedChoiceId
    else
        session.selectedChoice = nil
    end

    return currentCategory, currentOption
end

local function buildCategories(runtimeCatalog)
    local categoriesPayload = {}

    for i = 1, #runtimeCatalog.categories do
        local category = runtimeCatalog.categories[i]
        categoriesPayload[#categoriesPayload + 1] = {
            id = category.id,
            label = category.label,
            icon = category.icon,
            asset = category.asset,
            description = category.description,
            enabled = #category.options > 0,
            count = #category.options,
        }
    end

    return categoriesPayload
end

local function buildOptions(currentCategory)
    local optionsPayload = {}
    if not currentCategory then return optionsPayload end

    for i = 1, #currentCategory.options do
        local option = currentCategory.options[i]
        local installedLabel = locale('ui.unavailable')
        local installed = false

        for choiceIndex = 1, #option.choices do
            local choice = option.choices[choiceIndex]
            if choice.installed then
                installed = true
                installedLabel = choice.label
                break
            end
        end

        optionsPayload[#optionsPayload + 1] = {
            id = option.id,
            label = option.label,
            icon = option.icon,
            asset = option.asset,
            group = option.group,
            price = option.price,
            disabled = option.disabled,
            currentLabel = installedLabel,
            installed = installed,
            choiceCount = #option.choices,
            action = option.action,
        }
    end

    return optionsPayload
end

local function buildChoices(currentOption)
    local choicesPayload = {}
    local selectedPrice = 0

    if not currentOption then
        return choicesPayload, selectedPrice
    end

    for i = 1, #currentOption.choices do
        local choice = currentOption.choices[i]
        if choice.id == session.selectedChoice then
            selectedPrice = choice.price or 0
        end

        choicesPayload[#choicesPayload + 1] = summarizeChoice(choice)
    end

    return choicesPayload, selectedPrice
end

function payload.build(action)
    action = action or 'sync'

    local runtimeCatalog = catalog.build()
    local currentCategory, currentOption = ensureSelection(runtimeCatalog)
    local choicesPayload, selectedPrice = buildChoices(currentOption)

    return {
        catalog = runtimeCatalog,
        nui = {
            action = action,
            visible = action ~= 'close',
            currency = config.currency,
            currentCategory = session.selectedCategory,
            currentOption = session.selectedOption,
            currentChoice = session.selectedChoice,
            selectedPrice = selectedPrice,
            sessionTotal = session.sessionTotal,
            categories = buildCategories(runtimeCatalog),
            options = buildOptions(currentCategory),
            choices = choicesPayload,
            vehicle = runtimeCatalog.vehicle,
            locale = {
                title = locale('menus.main.title'),
                breadcrumbRoot = locale('ui.catalog'),
                sessionTotal = locale('ui.sessionTotal'),
                selectedPrice = locale('ui.selectedPrice'),
                installed = locale('ui.statusInstalled'),
                available = locale('ui.statusAvailable'),
                blocked = locale('ui.statusBlocked'),
                unavailable = locale('ui.unavailable'),
                noOptions = locale('ui.noOptions'),
                noChoices = locale('ui.noChoices'),
                emptyCategory = locale('ui.emptyCategory'),
                apply = locale('ui.apply'),
                preview = locale('ui.preview'),
                close = locale('ui.close'),
                hint = locale('ui.hint'),
                installedHint = locale('ui.installedHint'),
                actionHint = locale('ui.actionHint'),
                variations = locale('ui.variations'),
                previewFallback = locale('ui.previewFallback'),
            }
        }
    }
end

return payload
