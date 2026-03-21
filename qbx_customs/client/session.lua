local defaults = {
    isOpen = false,
    isClosing = false,
    zoneId = nil,
    zoneIndex = nil,
    vehicle = 0,
    vehicleNetId = 0,
    plate = nil,
    preview = nil,
    committedProps = nil,
    originalProps = nil,
    sessionTotal = 0,
    selections = {
        category = nil,
        option = nil,
        choice = nil,
    },
}

local session = table.clone(defaults)

local function resetSelections()
    session.selections = {
        category = nil,
        option = nil,
        choice = nil,
    }
end

function session.start(data)
    session.isOpen = true
    session.isClosing = false
    session.zoneId = data.zoneId
    session.zoneIndex = data.zoneIndex
    session.vehicle = data.vehicle or 0
    session.vehicleNetId = data.vehicleNetId or 0
    session.plate = data.plate
    session.preview = nil
    session.committedProps = nil
    session.originalProps = nil
    session.sessionTotal = 0
    resetSelections()
end

function session.setSelection(categoryId, optionId, choiceId)
    if categoryId ~= nil then
        session.selections.category = categoryId
    end

    if optionId ~= nil then
        session.selections.option = optionId
    end

    if choiceId ~= nil then
        session.selections.choice = choiceId
    end
end

function session.setPreview(preview)
    session.preview = preview and table.clone(preview) or nil
end

function session.clearPreview()
    session.preview = nil
end

function session.addToTotal(amount)
    session.sessionTotal = session.sessionTotal + math.max(0, math.floor(tonumber(amount) or 0))
end

function session.markClosing()
    session.isClosing = true
end

function session.reset()
    for key, value in pairs(defaults) do
        session[key] = type(value) == 'table' and table.clone(value) or value
    end
end

return session
