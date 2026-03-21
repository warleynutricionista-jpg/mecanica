local session = require 'client.session'
local actions = require 'client.actions'
local payloadBuilder = require 'client.ui_payload'
local validator = require 'client.services.validator'

local ui = {}
local runtimeCatalog

local uiState = {
    isUiOpen = false,
    isUiBusy = false,
    currentView = nil,
}

local function setFocus(hasFocus)
    SetNuiFocus(hasFocus, hasFocus)
    SetNuiFocusKeepInput(false)
end

local function resetUiState()
    runtimeCatalog = nil
    uiState.isUiOpen = false
    uiState.isUiBusy = false
    uiState.currentView = nil
end

local function rebuildPayload()
    local built = payloadBuilder.build('open')
    runtimeCatalog = built.catalog

    local payload = built.nui
    payload.type = 'custom'
    payload.show = true
    payload.visible = true
    payload.currentView = uiState.currentView or 'main'

    return payload
end

local function sendOpenPayload()
    SendNUIMessage(rebuildPayload())
end

local function sendClosePayload()
    SendNUIMessage({
        type = 'custom',
        show = false,
        visible = false,
        currentView = nil,
    })
end

local function refreshMenu()
    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    if not uiState.isUiOpen then
        return false, 'closed'
    end

    sendOpenPayload()
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

function ui.isOpen()
    return uiState.isUiOpen
end

function ui.isBusy()
    return uiState.isUiBusy
end

function ui.open(view)
    if uiState.isUiBusy or uiState.isUiOpen then
        return false, 'busy'
    end

    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    uiState.isUiBusy = true
    uiState.currentView = view or 'main'
    sendOpenPayload()
    setFocus(true)
    uiState.isUiOpen = true
    uiState.isUiBusy = false

    return true
end

function ui.refresh()
    return refreshMenu()
end

function ui.close()
    setFocus(false)
    sendClosePayload()
    resetUiState()
end

function ui.ensureClosed()
    setFocus(false)
    sendClosePayload()
    resetUiState()
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
