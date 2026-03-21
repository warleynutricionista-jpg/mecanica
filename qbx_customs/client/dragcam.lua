local angleY = 0.0
local angleZ = 0.0
local cam
local running = false
local targetEntity
local radius = 5.0
local radiusMax = 10.0
local radiusMin = 2.5
local scaleform
local scrollIncrement = 0.5
local isFirstPersonView = false

local function cos(degrees)
    return math.cos(math.rad(degrees))
end

local function sin(degrees)
    return math.sin(math.rad(degrees))
end

local function setCamPosition()
    if not running or not targetEntity or not DoesEntityExist(targetEntity) then return end

    local entityCoords = GetEntityCoords(targetEntity)
    local mouseX = GetDisabledControlNormal(0, 1) * 8.0
    local mouseY = GetDisabledControlNormal(0, 2) * 8.0

    angleZ -= mouseX
    angleY = lib.math.clamp(angleY + mouseY, 0.0, 89.0)

    local offset = vec3(
        cos(angleZ) * cos(angleY) * radius,
        sin(angleZ) * cos(angleY) * radius,
        sin(angleY) * radius
    )

    SetCamCoord(cam, entityCoords.x + offset.x, entityCoords.y + offset.y, entityCoords.z + offset.z)
    PointCamAtCoord(cam, entityCoords.x, entityCoords.y, entityCoords.z + 0.5)
end

local function disablePlayerMovement()
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 36, true)
    DisableControlAction(0, 47, true)
    DisableControlAction(0, 58, true)
    DisableControlAction(0, 69, true)
    DisableControlAction(0, 75, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 143, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
    DisableControlAction(0, 264, true)
end

local function disableCamMovement()
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0, 3, true)
    DisableControlAction(0, 4, true)
    DisableControlAction(0, 5, true)
    DisableControlAction(0, 6, true)
    DisableControlAction(0, 12, true)
    DisableControlAction(0, 13, true)
    DisableControlAction(0, 200, true)
end

local function instructionalButton(controlId, text)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, controlId, true))
    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()
end

local function showInstructionalButtons()
    CreateThread(function()
        scaleform = RequestScaleformMovie('instructional_buttons')
        while running and not HasScaleformMovieLoaded(scaleform) do
            Wait(0)
        end

        if not running then return end

        BeginScaleformMovieMethod(scaleform, 'CLEAR_ALL')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(1)
        instructionalButton(14, locale('dragCam.zoomOut'))
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(2)
        instructionalButton(15, locale('dragCam.zoomIn'))
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(3)
        instructionalButton(22, locale('dragCam.toggleDoors'))
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(4)
        instructionalButton(0, locale('dragCam.changeView'))
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_BACKGROUND_COLOUR')
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(80)
        EndScaleformMovieMethod()

        while running do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end
    end)
end

local function toggleVehicleDoors()
    local vehicle = cache.vehicle
    if not vehicle or vehicle ~= targetEntity then return end

    local doors = GetNumberOfVehicleDoors(vehicle)
    for i = 0, doors do
        if GetVehicleDoorAngleRatio(vehicle, i) > 0 then
            SetVehicleDoorShut(vehicle, i, false)
        else
            SetVehicleDoorOpen(vehicle, i, false, false)
        end
    end
end

local function startInputLoop()
    setCamPosition()

    CreateThread(function()
        local rotating = false

        while running do
            DisableControlAction(0, 0, true)
            disablePlayerMovement()

            if not isFirstPersonView then
                SetMouseCursorActiveThisFrame()
                disableCamMovement()

                if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
                    rotating = true
                    SetMouseCursorSprite(4)
                elseif rotating and (IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 24)) then
                    rotating = false
                    SetMouseCursorSprite(3)
                end

                if rotating then
                    setCamPosition()
                end
            end

            if IsDisabledControlJustReleased(0, 14) or IsControlJustReleased(0, 14) then
                radius = math.min(radius + scrollIncrement, radiusMax)
                setCamPosition()
            elseif IsDisabledControlJustReleased(0, 15) or IsControlJustReleased(0, 15) then
                radius = math.max(radius - scrollIncrement, radiusMin)
                setCamPosition()
            end

            if IsControlJustPressed(0, 22) then
                toggleVehicleDoors()
            end

            if IsDisabledControlJustPressed(0, 0) then
                isFirstPersonView = not isFirstPersonView
                if isFirstPersonView then
                    SetCamViewModeForContext(1, 4)
                    RenderScriptCams(false, true, 0, true, false)
                else
                    RenderScriptCams(true, true, 0, true, false)
                    setCamPosition()
                end
            end

            Wait(0)
        end
    end)
end

---@param entity integer
---@param radiusOptions? {initial?: number, min?: number, max?: number, scrollIncrements?: number}
local function startDragCam(entity, radiusOptions)
    if running then
        return
    end

    running = true
    targetEntity = entity
    radius = radiusOptions?.initial or 5.0
    radiusMin = radiusOptions?.min or 2.5
    radiusMax = radiusOptions?.max or 10.0
    scrollIncrement = radiusOptions?.scrollIncrements or 0.5
    angleY = 0.0
    angleZ = 0.0
    isFirstPersonView = false
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, true, 0, true, false)
    showInstructionalButtons()
    startInputLoop()
end

local function stopDragCam()
    if not running then return end

    running = false
    RenderScriptCams(false, true, 0, true, false)

    if cam then
        DestroyCam(cam, true)
        cam = nil
    end

    SetCamViewModeForContext(1, 1)

    if scaleform then
        SetScaleformMovieAsNoLongerNeeded(scaleform)
        scaleform = nil
    end

    targetEntity = nil
end

return {
    startDragCam = startDragCam,
    stopDragCam = stopDragCam
}
