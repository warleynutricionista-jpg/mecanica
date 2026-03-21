local defaults = {
    isOpen = false,
    isClosing = false,
    vehicle = 0,
    committedProps = nil,
    originalProps = nil,
    sessionTotal = 0,
    selectedCategory = nil,
    selectedOption = nil,
    selectedChoice = nil,
    previewOption = nil,
    previewChoice = nil,
    vehicleNetId = 0,
    previewState = nil,
    lastAppliedState = nil,
    isPreviewActive = false,
}

local session = table.clone(defaults)

local function resetSelections()
    session.selectedCategory = nil
    session.selectedOption = nil
    session.selectedChoice = nil
    session.previewOption = nil
    session.previewChoice = nil
end

function session.begin(vehicle)
    session.isOpen = true
    session.isClosing = false
    session.vehicle = vehicle or 0
    session.vehicleNetId = vehicle and vehicle ~= 0 and NetworkGetNetworkIdFromEntity(vehicle) or 0
    session.committedProps = nil
    session.originalProps = nil
    session.sessionTotal = 0
    session.previewState = nil
    session.lastAppliedState = nil
    session.isPreviewActive = false
    resetSelections()
end

function session.clearPreview()
    session.previewOption = nil
    session.previewChoice = nil
    session.previewState = nil
    session.isPreviewActive = false
end

function session.setPreview(optionId, choiceId)
    session.previewOption = optionId
    session.previewChoice = choiceId
    session.previewState = {
        optionId = optionId,
        choiceId = choiceId,
    }
    session.isPreviewActive = true
end

function session.setLastAppliedState(props)
    session.lastAppliedState = props and table.clone(props) or nil
end

function session.select(categoryId, optionId, choiceId)
    if categoryId ~= nil then
        session.selectedCategory = categoryId
    end

    if optionId ~= nil then
        session.selectedOption = optionId
    end

    if choiceId ~= nil then
        session.selectedChoice = choiceId
    end
end

function session.markClosing()
    session.isClosing = true
end

function session.addToTotal(amount)
    session.sessionTotal += amount or 0
end

function session.reset()
    for key, value in pairs(defaults) do
        session[key] = type(value) == 'table' and table.clone(value) or value
    end
end

return session
