local session = require 'client.session'
local actions = require 'client.actions'
local payloadBuilder = require 'client.ui_payload'
local validator = require 'client.services.validator'

local ui = {}
local runtimeCatalog

local function rebuildPayload()
    local built = payloadBuilder.build()
    runtimeCatalog = built.catalog
    return built.nui
end

local function refreshMenu()
    local ok, reason = validator.ensureActiveSession()
    if not ok and reason ~= 'closed' then
        return false
    end

    SendNUIMessage(rebuildPayload())
    return true
end

function ui.open()
    SetNuiFocus(true, true)
    SendNUIMessage(rebuildPayload())
end

function ui.refresh()
    refreshMenu()
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
    if session.selectedCategory == categoryId then return end

    actions.restoreCommitted()
    session.selectedCategory = categoryId
    session.selectedOption = nil
    session.selectedChoice = nil
    refreshMenu()
end

function ui.selectOption(optionId)
    if session.selectedOption == optionId then return end

    actions.restoreCommitted()
    session.selectedOption = optionId
    session.selectedChoice = nil
    refreshMenu()
end

function ui.previewChoice(optionId, choiceId)
    local option = ui.getOption(optionId)
    if not option or session.previewChoice == choiceId then return end

    for _, choice in ipairs(option.choices) do
        if choice.id == choiceId then
            session.selectedChoice = choiceId
            if not choice.isAction then
                actions.applyPreview(option, choice)
            end
            break
        end
    end

    refreshMenu()
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

    refreshMenu()
end

return ui
