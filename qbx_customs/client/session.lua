local session = {
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
}

function session.reset()
    session.isOpen = false
    session.isClosing = false
    session.vehicle = 0
    session.committedProps = nil
    session.originalProps = nil
    session.sessionTotal = 0
    session.selectedCategory = nil
    session.selectedOption = nil
    session.selectedChoice = nil
    session.previewOption = nil
    session.previewChoice = nil
end

return session
