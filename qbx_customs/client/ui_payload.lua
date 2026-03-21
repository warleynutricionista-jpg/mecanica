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

local function ensureSelection(runtimeCatalog)
    local selectedCategory = session.selectedCategory
    local currentCategory

    for _, category in ipairs(runtimeCatalog.categories) do
        if category.enabled and not selectedCategory then
            selectedCategory = category.id
        end

        if category.id == selectedCategory then
            currentCategory = category
        end
    end

    session.selectedCategory = selectedCategory

    if currentCategory and (not session.selectedOption or not runtimeCatalog.options[session.selectedOption]) then
        session.selectedOption = currentCategory.options[1] and currentCategory.options[1].id or nil
    end

    local currentOption = session.selectedOption and runtimeCatalog.options[session.selectedOption] or nil
    if currentOption and not session.selectedChoice then
        for _, choice in ipairs(currentOption.choices) do
            if choice.installed then
                session.selectedChoice = choice.id
                break
            end
        end

        if not session.selectedChoice and currentOption.choices[1] then
            session.selectedChoice = currentOption.choices[1].id
        end
    end

    return currentCategory, currentOption
end

local function buildCategories(runtimeCatalog)
    local categoriesPayload = {}

    for _, category in ipairs(runtimeCatalog.categories) do
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

    for _, option in ipairs(currentCategory.options) do
        local installedLabel = locale('ui.unavailable')
        local installed = false

        for _, choice in ipairs(option.choices) do
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

    for _, choice in ipairs(currentOption.choices) do
        if choice.id == session.selectedChoice then
            selectedPrice = choice.price or 0
        end
        choicesPayload[#choicesPayload + 1] = summarizeChoice(choice)
    end

    return choicesPayload, selectedPrice
end

function payload.build()
    local runtimeCatalog = catalog.build()
    local currentCategory, currentOption = ensureSelection(runtimeCatalog)
    local choicesPayload, selectedPrice = buildChoices(currentOption)

    return {
        catalog = runtimeCatalog,
        nui = {
            action = 'open',
            visible = true,
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
            }
        }
    }
end

return payload
