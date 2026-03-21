local session = require 'client.session'
local actions = require 'client.actions'
local payloadBuilder = require 'client.ui_payload'
local validator = require 'client.services.validator'

local ui = {}
local runtimeCatalog

local uiState = {
    isUiOpen = false,
    isUiLoaded = false,
    isUiBusy = false,
    currentView = nil,
    lastOpenAt = 0,
}

local function setFocus(hasFocus, keepInput)
    SetNuiFocus(hasFocus, hasFocus)
    SetNuiFocusKeepInput(hasFocus and keepInput or false)
end

local function resetUiState()
    runtimeCatalog = nil
    uiState.isUiOpen = false
    uiState.isUiBusy = false
    uiState.currentView = nil
    uiState.lastOpenAt = 0
end

local function rebuildPayload(action, extra)
    local built = payloadBuilder.build(action)
    runtimeCatalog = built.catalog

    local payload = built.nui
    if extra then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end

    payload.uiState = {
        isOpen = uiState.isUiOpen,
        isBusy = uiState.isUiBusy,
        isLoaded = uiState.isUiLoaded,
        currentView = uiState.currentView,
    }

    return payload
end

local function sendMessage(payload)
    SendNUIMessage(payload)
end

local function refreshMenu()
    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    if not uiState.isUiOpen then
        return false, 'uiClosed'
    end

    sendMessage(rebuildPayload('sync', {
        visible = true,
        currentView = uiState.currentView,
        overlay = false,
        focus = true,
    }))

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

function ui.markLoaded()
    uiState.isUiLoaded = true
    resetUiState()
    setFocus(false, false)
    sendMessage({
        action = 'hardReset',
        visible = false,
        overlay = false,
        currentView = nil,
    })
end

function ui.isOpen()
    return uiState.isUiOpen
end

function ui.isBusy()
    return uiState.isUiBusy
end

function ui.open(view)
    if not uiState.isUiLoaded then
        return false, 'busy'
    end

    if uiState.isUiBusy then
        return false, 'busy'
    end

    if uiState.isUiOpen then
        return false, 'alreadyOpen'
    end

    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    uiState.isUiBusy = true
    uiState.currentView = view or 'main'
    uiState.isUiOpen = true

    local payload = rebuildPayload('open', {
        visible = true,
        currentView = uiState.currentView,
        overlay = false,
        focus = true,
    })

    sendMessage(payload)
    setFocus(true, false)

    uiState.lastOpenAt = GetGameTimer()
    uiState.isUiBusy = false

    return true
end

function ui.refresh()
    return refreshMenu()
end

function ui.close(reason)
    setFocus(false, false)
    resetUiState()
    sendMessage({
        action = 'hardReset',
        visible = false,
        overlay = false,
        currentView = nil,
        reason = reason,
    })
end

function ui.forceReset(reason)
    actions.restoreCommitted()
    ui.close(reason or 'forcedReset')
end

function ui.ensureClosed(reason)
    if session.isOpen or uiState.isUiOpen or uiState.isUiBusy then
        ui.forceReset(reason or 'desync')
    else
        setFocus(false, false)
        sendMessage({
            action = 'hardReset',
            visible = false,
            overlay = false,
            currentView = nil,
            reason = reason or 'idleReset',
        })
    end
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
