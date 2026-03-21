local session = require 'client.session'
local actions = require 'client.actions'
local payloadBuilder = require 'client.ui_payload'
local validator = require 'client.services.validator'

local ui = {}
local runtimeCatalog

local function rebuildPayload(action)
    local built = payloadBuilder.build(action)
    runtimeCatalog = built.catalog
    return built.nui
end

local function refreshMenu()
    local ok, reason = validator.ensureActiveSession()
    if not ok and reason ~= 'closed' then
        return false
    end

    SendNUIMessage(rebuildPayload('sync'))
    return true
end

local function getChoice(option, choiceId)
    if not option or not option.choices then
        return nil
    end

    for i = 1, #option.choices do
        local choice = option.choices[i]
        if choice.id == choiceId then
            return choice
        end
    end

    return nil
end

function ui.open()
    SendNUIMessage(rebuildPayload('open'))
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

function ui.refresh()
    refreshMenu()
end

function ui.hide()
    runtimeCatalog = nil
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

function ui.getOption(optionId)
    if not runtimeCatalog then
        return nil
    end

    return runtimeCatalog.options[optionId]
end

function ui.selectCategory(categoryId)
    if session.selectedCategory == categoryId then
        return
    end

    actions.restoreCommitted()
    session.select(categoryId, nil, nil)
    session.selectedOption = nil
    session.selectedChoice = nil
    refreshMenu()
end

function ui.selectOption(optionId)
    if session.selectedOption == optionId then
        return
    end

    actions.restoreCommitted()
    session.select(nil, optionId, nil)
    session.selectedChoice = nil
    refreshMenu()
end

function ui.previewChoice(optionId, choiceId)
    local option = ui.getOption(optionId)
    if not option or (session.previewOption == optionId and session.previewChoice == choiceId) then
        return
    end

    local choice = getChoice(option, choiceId)
    if not choice then
        return
    end

    session.selectedChoice = choiceId
    if not choice.isAction then
        actions.applyPreview(option, choice)
    end

    refreshMenu()
end

function ui.installChoice(optionId, choiceId)
    local option = ui.getOption(optionId)
    if not option then
        return
    end

    local choice = getChoice(option, choiceId)
    if not choice then
        return
    end

    session.selectedChoice = choiceId

    if choice.action == 'repair' then
        actions.restoreCommitted()
        actions.repairVehicle(choice.price)
    else
        local previewApplied = choice.installed or actions.applyPreview(option, choice)
        if previewApplied then
            actions.commitChoice(option, choice)
        end
    end

    refreshMenu()
end

return ui
