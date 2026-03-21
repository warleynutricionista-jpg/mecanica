local clientConfig = require 'config.client'
local session = require 'client.session'
local catalogBuilder = require 'client.catalog'
local feedback = require 'client.services.feedback'
local vehicleService = require 'client.services.vehicle'
local access = require 'client.services.access'

local menu = {}

local ROOT_ID = 'qbx_customs:root'
local OPTIONS_ID = 'qbx_customs:options'
local CHOICES_ID = 'qbx_customs:choices'

local state = {
    closeHandler = nil,
    watcherRunning = false,
    runtime = nil,
}

local function requestClose(reason)
    if state.closeHandler then
        state.closeHandler(reason)
    end
end

local function findCategory(categoryId)
    if not state.runtime then
        return nil
    end

    for i = 1, #state.runtime.categories do
        local category = state.runtime.categories[i]
        if category.id == categoryId then
            return category
        end
    end

    return nil
end

local function findOption(optionId)
    if not state.runtime then
        return nil
    end

    for i = 1, #state.runtime.categories do
        local category = state.runtime.categories[i]
        for j = 1, #category.options do
            if category.options[j].id == optionId then
                return category.options[j], category
            end
        end
    end

    return nil, nil
end

local function findChoice(option, choiceId)
    if not option then
        return nil
    end

    for i = 1, #option.choices do
        if option.choices[i].id == choiceId then
            return option.choices[i]
        end
    end

    return nil
end

local function formatNumber(value)
    local formatted = tostring(math.floor(tonumber(value) or 0))
    while true do
        local replaced
        formatted, replaced = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1.%2')
        if replaced == 0 then
            break
        end
    end
    return formatted
end

local function moneyLabel(choice)
    if access.isFreeService(session.zoneIndex, choice.serviceType) then
        return locale('ui.free')
    end

    return ('%s%s'):format(clientConfig.currency, formatNumber(choice.price or 0))
end

local function rebuild()
    state.runtime = catalogBuilder.build()
    if not session.selections.category or not findCategory(session.selections.category) then
        for i = 1, #state.runtime.categories do
            if #state.runtime.categories[i].options > 0 then
                session.selections.category = state.runtime.categories[i].id
                break
            end
        end
    end

    local option = session.selections.option and select(1, findOption(session.selections.option)) or nil
    if not option then
        local category = findCategory(session.selections.category)
        if category and category.options[1] then
            session.selections.option = category.options[1].id
            option = category.options[1]
        else
            session.selections.option = nil
        end
    end

    if option then
        local choice = session.selections.choice and findChoice(option, session.selections.choice) or nil
        if not choice then
            for i = 1, #option.choices do
                if option.choices[i].installed then
                    session.selections.choice = option.choices[i].id
                    choice = option.choices[i]
                    break
                end
            end
        end
        if not choice and option.choices[1] then
            session.selections.choice = option.choices[1].id
        end
    else
        session.selections.choice = nil
    end
end

local function registerRoot()
    local options = {}
    for i = 1, #state.runtime.categories do
        local category = state.runtime.categories[i]
        options[#options + 1] = {
            title = category.label,
            description = category.description,
            icon = category.icon,
            disabled = #category.options == 0,
            metadata = {
                { label = locale('ui.variations'), value = tostring(#category.options) },
            },
            onSelect = function()
                session.setSelection(category.id, nil, nil)
            end,
            menu = #category.options > 0 and OPTIONS_ID or nil,
        }
    end

    options[#options + 1] = {
        title = locale('ui.close'),
        description = state.runtime.vehicle.plate,
        icon = 'xmark',
        iconColor = '#ef4444',
        onSelect = function()
            requestClose('closeAction')
        end,
    }

    lib.registerContext({
        id = ROOT_ID,
        title = ('%s · %s'):format(locale('menus.main.title'), state.runtime.vehicle.name),
        canClose = true,
        options = options,
    })
end

local function registerOptions()
    local entries = {}
    local category = findCategory(session.selections.category)
    if category then
        for i = 1, #category.options do
            local option = category.options[i]
            local installedLabel = locale('ui.unavailable')
            for j = 1, #option.choices do
                if option.choices[j].installed then
                    installedLabel = option.choices[j].label
                    break
                end
            end

            entries[#entries + 1] = {
                title = option.label,
                description = ('%s · %s'):format(option.group, installedLabel),
                icon = option.icon,
                metadata = {
                    { label = locale('ui.variations'), value = tostring(#option.choices) },
                },
                onSelect = function()
                    session.setSelection(nil, option.id, nil)
                end,
                menu = CHOICES_ID,
            }
        end
    end

    if #entries == 0 then
        entries[#entries + 1] = {
            title = locale('ui.emptyCategory'),
            disabled = true,
            icon = 'triangle-exclamation',
        }
    end

    lib.registerContext({
        id = OPTIONS_ID,
        title = category and category.label or locale('ui.emptyCategory'),
        menu = ROOT_ID,
        canClose = true,
        options = entries,
    })
end

local function registerChoices(previewHandler, applyHandler, cancelPreviewHandler)
    local entries = {}
    local option = select(1, findOption(session.selections.option))
    local currentChoice = option and findChoice(option, session.selections.choice) or nil

    if session.preview and currentChoice then
        entries[#entries + 1] = {
            title = locale('ui.apply'),
            description = ('%s · %s'):format(currentChoice.label, moneyLabel(currentChoice)),
            icon = 'check',
            iconColor = '#22c55e',
            disabled = currentChoice.installed or currentChoice.blocked,
            onSelect = function()
                applyHandler(option, currentChoice)
            end,
        }

        entries[#entries + 1] = {
            title = locale('ui.cancelPreview'),
            description = locale('ui.restorePreview'),
            icon = 'rotate-left',
            onSelect = function()
                cancelPreviewHandler()
            end,
        }
    end

    if option then
        for i = 1, #option.choices do
            local choice = option.choices[i]
            local status = locale('ui.statusAvailable')
            if choice.installed then
                status = locale('ui.statusInstalled')
            elseif choice.blocked then
                status = locale('ui.statusBlocked')
            end

            entries[#entries + 1] = {
                title = choice.label,
                description = choice.isAction and locale('ui.actionHint') or status,
                icon = choice.installed and 'circle-check' or 'screwdriver-wrench',
                iconColor = choice.installed and '#22c55e' or nil,
                disabled = choice.blocked,
                metadata = {
                    { label = locale('ui.selectedPrice'), value = moneyLabel(choice) },
                    { label = locale('ui.status'), value = status },
                },
                onSelect = function()
                    previewHandler(option, choice)
                end,
            }
        end
    end

    if #entries == 0 then
        entries[#entries + 1] = {
            title = locale('ui.noChoices'),
            disabled = true,
            icon = 'triangle-exclamation',
        }
    end

    lib.registerContext({
        id = CHOICES_ID,
        title = option and option.label or locale('ui.previewFallback'),
        menu = OPTIONS_ID,
        canClose = true,
        options = entries,
    })
end

local function startWatcher()
    if state.watcherRunning then
        return
    end

    state.watcherRunning = true
    CreateThread(function()
        Wait(250)
        while session.isOpen do
            local openMenu = lib.getOpenContextMenu and lib.getOpenContextMenu() or nil
            if not openMenu then
                requestClose('contextClosed')
                break
            end
            Wait(200)
        end
        state.watcherRunning = false
    end)
end

function menu.setCloseHandler(callback)
    state.closeHandler = callback
end

function menu.refresh(previewHandler, applyHandler, cancelPreviewHandler, targetContext)
    rebuild()
    registerRoot()
    registerOptions()
    registerChoices(previewHandler, applyHandler, cancelPreviewHandler)
    lib.showContext(targetContext or ROOT_ID)
end

function menu.open(previewHandler, applyHandler, cancelPreviewHandler)
    menu.refresh(previewHandler, applyHandler, cancelPreviewHandler, ROOT_ID)
    startWatcher()
end

function menu.close()
    if lib.hideContext then
        lib.hideContext(false)
    end
end

return menu
