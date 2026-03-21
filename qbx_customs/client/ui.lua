local session = require 'client.session'
local catalog = require 'client.catalog'
local actions = require 'client.actions'
local config = require 'config.client'

local ui = {}
local runtimeCatalog

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

local function buildPayload()
    runtimeCatalog = catalog.build()

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
    if currentOption and (not session.selectedChoice) then
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

    local categoriesPayload = {}
    for _, category in ipairs(runtimeCatalog.categories) do
        local count = #category.options
        categoriesPayload[#categoriesPayload + 1] = {
            id = category.id,
            label = category.label,
            icon = category.icon,
            asset = category.asset,
            description = category.description,
            enabled = count > 0,
            count = count,
        }
    end

    local optionsPayload = {}
    if currentCategory then
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
    end

    local choicesPayload = {}
    local selectedPrice = 0
    if currentOption then
        for _, choice in ipairs(currentOption.choices) do
            if choice.id == session.selectedChoice then
                selectedPrice = choice.price or 0
            end
            choicesPayload[#choicesPayload + 1] = summarizeChoice(choice)
        end
    end

    return {
        action = 'open',
        visible = true,
        currency = config.currency,
        currentCategory = session.selectedCategory,
        currentOption = session.selectedOption,
        currentChoice = session.selectedChoice,
        selectedPrice = selectedPrice,
        sessionTotal = session.sessionTotal,
        categories = categoriesPayload,
        options = optionsPayload,
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
end

function ui.open()
    local payload = buildPayload()
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

function ui.refresh()
    SendNUIMessage(buildPayload())
end

function ui.hide()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function ui.getOption(optionId)
    if not runtimeCatalog then return nil end
    return runtimeCatalog.options[optionId]
end

function ui.selectCategory(categoryId)
    actions.restoreCommitted()
    session.selectedCategory = categoryId
    session.selectedOption = nil
    session.selectedChoice = nil
    ui.refresh()
end

function ui.selectOption(optionId)
    actions.restoreCommitted()
    session.selectedOption = optionId
    session.selectedChoice = nil
    ui.refresh()
end

function ui.previewChoice(optionId, choiceId)
    local option = ui.getOption(optionId)
    if not option then return end

    for _, choice in ipairs(option.choices) do
        if choice.id == choiceId then
            session.selectedChoice = choiceId
            if not choice.isAction then
                actions.applyPreview(option, choice)
            end
            break
        end
    end

    ui.refresh()
end

function ui.installChoice(optionId, choiceId)
    local option = ui.getOption(optionId)
    if not option then return end

    for _, choice in ipairs(option.choices) do
        if choice.id == choiceId then
            session.selectedChoice = choiceId
            if choice.action == 'repair' then
                actions.restoreCommitted()
                actions.repairVehicle(choice.price)
            else
                actions.applyPreview(option, choice)
                actions.commitChoice(option, choice)
            end
            break
        end
    end

    ui.refresh()
end

return ui
