local session = require 'client.session'
local actions = require 'client.actions'
local payloadBuilder = require 'client.ui_payload'
local validator = require 'client.services.validator'
local vehicle = require 'client.services.vehicle'

local ui = {}

local ROOT_CONTEXT_ID = 'qbx_customs:root'
local OPTIONS_CONTEXT_ID = 'qbx_customs:options'
local CHOICES_CONTEXT_ID = 'qbx_customs:choices'

local runtimeCatalog
local runtimePayload
local closeHandler
local watcherRunning = false

local uiState = {
    isCustomsOpen = false,
    isPreviewActive = false,
    isCameraActive = false,
    currentCategory = nil,
    currentOption = nil,
    currentSelection = nil,
    isBusy = false,
    hasFocus = false,
    vehicleNetId = 0,
    vehicleEntity = 0,
    lastAppliedState = nil,
    previewState = nil,
    activeContextId = nil,
}

local function cloneState(value)
    if type(value) ~= 'table' then
        return value
    end

    return table.clone(value)
end

local function formatPrice(value)
    local numericValue = math.floor(tonumber(value) or 0)
    local formatted = tostring(numericValue)

    while true do
        local replaced
        formatted, replaced = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1.%2')
        if replaced == 0 then
            break
        end
    end

    local currency = runtimePayload and runtimePayload.currency or 'R$'
    return ('%s%s'):format(currency, formatted)
end

local function syncStateFromSession()
    uiState.currentCategory = session.selectedCategory
    uiState.currentOption = session.selectedOption
    uiState.currentSelection = session.selectedChoice
    uiState.vehicleEntity = session.vehicle or 0
    uiState.vehicleNetId = session.vehicleNetId or 0
    uiState.lastAppliedState = cloneState(session.lastAppliedState)
    uiState.previewState = cloneState(session.previewState)
    uiState.isPreviewActive = session.isPreviewActive == true
end

function ui.SetCustomsFocus(state)
    uiState.hasFocus = state == true
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if type(SetNuiZIndex) == 'function' then
        SetNuiZIndex(0)
    end
end

function ui.ResetCustomsVisualState()
    if type(lib.hideContext) == 'function' then
        lib.hideContext(false)
    end

    if type(lib.hideTextUI) == 'function' then
        lib.hideTextUI()
    end

    ui.SetCustomsFocus(false)
    uiState.activeContextId = nil
end

function ui.HardResetCustomsUI()
    runtimeCatalog = nil
    runtimePayload = nil
    ui.ResetCustomsVisualState()

    uiState.isCustomsOpen = false
    uiState.isPreviewActive = false
    uiState.currentCategory = nil
    uiState.currentOption = nil
    uiState.currentSelection = nil
    uiState.isBusy = false
    uiState.vehicleNetId = 0
    uiState.vehicleEntity = 0
    uiState.lastAppliedState = nil
    uiState.previewState = nil
end

local function rebuildRuntime()
    local built = payloadBuilder.build('sync')
    runtimeCatalog = built.catalog
    runtimePayload = built.nui
    syncStateFromSession()
    return true
end

local function setActiveContext(contextId)
    uiState.activeContextId = contextId
    ui.SetCustomsFocus(true)
    lib.showContext(contextId)
end

local function requestClose(reason)
    if type(closeHandler) == 'function' then
        closeHandler(reason or 'contextClosed')
    else
        ui.CloseCustomsUI(reason)
    end
end

local function getCurrentOption()
    if not runtimeCatalog or not uiState.currentOption then
        return nil
    end

    return runtimeCatalog.options[uiState.currentOption]
end

local function getCurrentChoice()
    local option = getCurrentOption()
    if not option or not option.choices then
        return nil
    end

    for i = 1, #option.choices do
        local choice = option.choices[i]
        if choice.id == uiState.currentSelection then
            return choice
        end
    end

    return nil
end

local function startContextWatcher()
    if watcherRunning then
        return
    end

    watcherRunning = true

    CreateThread(function()
        while uiState.isCustomsOpen do
            Wait(150)

            if not uiState.isCustomsOpen then
                break
            end

            local openContextId = uiState.activeContextId
            if type(lib.getOpenContextMenu) == 'function' then
                openContextId = lib.getOpenContextMenu()
            end

            if not openContextId then
                requestClose('contextClosed')
                break
            end
        end

        watcherRunning = false
    end)
end

local function buildRootOptions()
    local options = {}

    for _, category in ipairs(runtimePayload.categories) do
        options[#options + 1] = {
            title = category.label,
            description = category.description,
            icon = 'list',
            arrow = category.enabled,
            disabled = not category.enabled,
            metadata = {
                { label = runtimePayload.locale.variations, value = tostring(category.count) },
            },
            onSelect = function()
                ui.selectCategory(category.id)
                ui.showOptionsMenu()
            end,
        }
    end

    options[#options + 1] = {
        title = runtimePayload.locale.close,
        description = runtimePayload.vehicle.name,
        icon = 'xmark',
        iconColor = '#ef4444',
        onSelect = function()
            requestClose('closeAction')
        end,
    }

    return options
end

local function buildOptionsMenuEntries()
    local entries = {}
    local categoryLabel = runtimePayload.locale.emptyCategory

    for i = 1, #runtimePayload.categories do
        local category = runtimePayload.categories[i]
        if category.id == uiState.currentCategory then
            categoryLabel = category.label
            break
        end
    end

    for _, option in ipairs(runtimePayload.options) do
        entries[#entries + 1] = {
            title = option.label,
            description = ('%s · %s'):format(option.group, option.currentLabel),
            icon = 'wrench',
            arrow = not option.disabled,
            disabled = option.disabled,
            metadata = {
                { label = runtimePayload.locale.selectedPrice, value = formatPrice(option.price) },
                { label = runtimePayload.locale.variations, value = tostring(option.choiceCount) },
            },
            onSelect = function()
                ui.selectOption(option.id)
                ui.showChoicesMenu()
            end,
        }
    end

    if #entries == 0 then
        entries[#entries + 1] = {
            title = categoryLabel,
            description = runtimePayload.locale.noOptions,
            disabled = true,
            icon = 'triangle-exclamation',
        }
    end

    entries[#entries + 1] = {
        title = runtimePayload.locale.close,
        description = runtimePayload.vehicle.plate,
        icon = 'xmark',
        iconColor = '#ef4444',
        onSelect = function()
            requestClose('closeAction')
        end,
    }

    return entries, categoryLabel
end

local function applyCurrentPreview()
    local option = getCurrentOption()
    local choice = getCurrentChoice()
    if not option or not choice or choice.blocked or choice.installed then
        return false
    end

    local previewApplied = choice.isAction or actions.applyPreview(option, choice)
    if not previewApplied and not choice.isAction then
        return false
    end

    if choice.action == 'repair' then
        local confirmed = lib.alertDialog({
            header = option.label,
            content = ('%s\n\n%s'):format(choice.label, formatPrice(choice.price)),
            centered = true,
            cancel = true,
            labels = {
                confirm = runtimePayload.locale.apply,
                cancel = runtimePayload.locale.close,
            }
        })

        if confirmed ~= 'confirm' then
            actions.restoreCommitted()
            rebuildRuntime()
            return false
        end
    end

    ui.installChoice(option.id, choice.id)
    ui.showChoicesMenu()
    return true
end

local function buildChoiceMenuEntries()
    local entries = {}
    local option = getCurrentOption()
    local choice = getCurrentChoice()

    if uiState.isPreviewActive and option and choice and choice.action ~= 'repair' then
        entries[#entries + 1] = {
            title = runtimePayload.locale.apply,
            description = ('%s · %s'):format(choice.label, formatPrice(choice.price)),
            icon = 'check',
            iconColor = '#22c55e',
            disabled = choice.blocked or choice.installed,
            onSelect = function()
                applyCurrentPreview()
            end,
        }

        entries[#entries + 1] = {
            title = 'Restaurar preview',
            description = runtimePayload.locale.installedHint,
            icon = 'rotate-left',
            onSelect = function()
                actions.restoreCommitted()
                rebuildRuntime()
                ui.showChoicesMenu()
            end,
        }
    end

    for _, entry in ipairs(runtimePayload.choices) do
        local statusLabel = runtimePayload.locale.statusAvailable
        if entry.blocked then
            statusLabel = runtimePayload.locale.statusBlocked
        elseif entry.installed then
            statusLabel = runtimePayload.locale.statusInstalled
        end

        entries[#entries + 1] = {
            title = entry.label,
            description = entry.isAction and runtimePayload.locale.actionHint or statusLabel,
            icon = entry.installed and 'circle-check' or 'screwdriver-wrench',
            iconColor = entry.installed and '#22c55e' or nil,
            disabled = entry.blocked,
            metadata = {
                { label = runtimePayload.locale.selectedPrice, value = formatPrice(entry.price) },
                { label = 'Status', value = statusLabel },
            },
            onSelect = function()
                if entry.isAction then
                    session.selectedChoice = entry.id
                    uiState.currentSelection = entry.id
                    rebuildRuntime()
                    applyCurrentPreview()
                    return
                end

                ui.previewChoice(uiState.currentOption, entry.id)
                ui.showChoicesMenu()
            end,
        }
    end

    if #runtimePayload.choices == 0 then
        entries[#entries + 1] = {
            title = option and option.label or runtimePayload.locale.previewFallback,
            description = runtimePayload.locale.noChoices,
            disabled = true,
            icon = 'triangle-exclamation',
        }
    end

    entries[#entries + 1] = {
        title = runtimePayload.locale.close,
        description = runtimePayload.vehicle.class,
        icon = 'xmark',
        iconColor = '#ef4444',
        onSelect = function()
            requestClose('closeAction')
        end,
    }

    return entries, option
end

local function registerContexts()
    local optionEntries, categoryLabel = buildOptionsMenuEntries()
    local choiceEntries, option = buildChoiceMenuEntries()

    lib.registerContext({
        id = ROOT_CONTEXT_ID,
        title = ('%s · %s'):format(locale('menus.main.title'), runtimePayload.vehicle.name),
        canClose = true,
        options = buildRootOptions(),
    })

    lib.registerContext({
        id = OPTIONS_CONTEXT_ID,
        title = categoryLabel,
        menu = ROOT_CONTEXT_ID,
        canClose = true,
        options = optionEntries,
    })

    lib.registerContext({
        id = CHOICES_CONTEXT_ID,
        title = option and option.label or runtimePayload.locale.previewFallback,
        menu = OPTIONS_CONTEXT_ID,
        canClose = true,
        options = choiceEntries,
    })
end

local function refreshMenu(targetContextId)
    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    if not uiState.isCustomsOpen then
        return false, 'closed'
    end

    rebuildRuntime()
    registerContexts()

    if targetContextId then
        setActiveContext(targetContextId)
    end

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

function ui.setCloseHandler(callback)
    closeHandler = callback
end

function ui.setCameraActive(state)
    uiState.isCameraActive = state == true
end

function ui.isOpen()
    return uiState.isCustomsOpen
end

function ui.isBusy()
    return uiState.isBusy
end

function ui.getState()
    return cloneState(uiState)
end

function ui.OpenCustomsUI()
    if uiState.isBusy or uiState.isCustomsOpen then
        return false, 'busy'
    end

    local ok, reason = validator.ensureActiveSession()
    if not ok then
        return false, reason
    end

    uiState.isBusy = true
    uiState.isCustomsOpen = true
    rebuildRuntime()
    registerContexts()
    setActiveContext(ROOT_CONTEXT_ID)
    startContextWatcher()
    uiState.isBusy = false

    return true
end

function ui.showRootMenu()
    refreshMenu(ROOT_CONTEXT_ID)
end

function ui.showOptionsMenu()
    refreshMenu(OPTIONS_CONTEXT_ID)
end

function ui.showChoicesMenu()
    refreshMenu(CHOICES_CONTEXT_ID)
end

function ui.refresh(targetContextId)
    return refreshMenu(targetContextId or uiState.activeContextId or ROOT_CONTEXT_ID)
end

function ui.CloseCustomsUI()
    ui.HardResetCustomsUI()
end

function ui.ensureClosed()
    ui.HardResetCustomsUI()
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
    session.clearPreview()
    rebuildRuntime()
end

function ui.selectOption(optionId)
    if session.selectedOption == optionId then
        return
    end

    actions.restoreCommitted()
    session.select(nil, optionId, nil)
    session.selectedChoice = nil
    session.clearPreview()
    rebuildRuntime()
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

    rebuildRuntime()
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

    rebuildRuntime()
end

ui.open = ui.OpenCustomsUI
ui.close = ui.CloseCustomsUI
ui.hardReset = ui.HardResetCustomsUI
ui.setFocus = ui.SetCustomsFocus
ui.resetVisualState = ui.ResetCustomsVisualState

return ui
