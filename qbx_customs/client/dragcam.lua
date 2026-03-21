local cameraState = {
    angleY = 0.0,
    angleZ = 0.0,
    cam = nil,
    running = false,
    scaleform = nil,
    targetEntity = nil,
    radius = 5.0,
    radiusMin = 2.5,
    radiusMax = 10.0,
    scrollIncrement = 0.5,
    isFirstPersonView = false,
}

local PLAYER_CONTROL_BLOCKS = { 21, 24, 25, 30, 31, 36, 47, 58, 69, 75, 140, 141, 142, 143, 257, 263, 264 }
local CAMERA_CONTROL_BLOCKS = { 1, 2, 3, 4, 5, 6, 12, 13, 200 }

local function cos(degrees)
    return math.cos(math.rad(degrees))
end

local function sin(degrees)
    return math.sin(math.rad(degrees))
end

local function disableControls(controlList)
    for i = 1, #controlList do
        DisableControlAction(0, controlList[i], true)
    end
end

local function isTargetValid()
    return cameraState.running and cameraState.targetEntity and DoesEntityExist(cameraState.targetEntity)
end

local function setCamPosition()
    if not isTargetValid() or not cameraState.cam then
        return false
    end

    local entityCoords = GetEntityCoords(cameraState.targetEntity)
    local mouseX = GetDisabledControlNormal(0, 1) * 8.0
    local mouseY = GetDisabledControlNormal(0, 2) * 8.0

    cameraState.angleZ -= mouseX
    cameraState.angleY = lib.math.clamp(cameraState.angleY + mouseY, 0.0, 89.0)

    local offset = vec3(
        cos(cameraState.angleZ) * cos(cameraState.angleY) * cameraState.radius,
        sin(cameraState.angleZ) * cos(cameraState.angleY) * cameraState.radius,
        sin(cameraState.angleY) * cameraState.radius
    )

    SetCamCoord(cameraState.cam, entityCoords.x + offset.x, entityCoords.y + offset.y, entityCoords.z + offset.z)
    PointCamAtCoord(cameraState.cam, entityCoords.x, entityCoords.y, entityCoords.z + 0.5)
    return true
end

local function instructionalButton(controlId, text)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, controlId, true))
    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()
end

local function releaseScaleform()
    if cameraState.scaleform then
        SetScaleformMovieAsNoLongerNeeded(cameraState.scaleform)
        cameraState.scaleform = nil
    end
end

local function showInstructionalButtons()
    CreateThread(function()
        local scaleform = RequestScaleformMovie('instructional_buttons')
        cameraState.scaleform = scaleform

        while cameraState.running and not HasScaleformMovieLoaded(scaleform) do
            Wait(0)
        end

        if not cameraState.running or cameraState.scaleform ~= scaleform then
            releaseScaleform()
            return
        end

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

        while cameraState.running and cameraState.scaleform == scaleform do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end

        releaseScaleform()
    end)
end

local function toggleVehicleDoors()
    if not isTargetValid() then return end

    local doors = GetNumberOfVehicleDoors(cameraState.targetEntity) - 1
    for door = 0, doors do
        if GetVehicleDoorAngleRatio(cameraState.targetEntity, door) > 0 then
            SetVehicleDoorShut(cameraState.targetEntity, door, false)
        else
            SetVehicleDoorOpen(cameraState.targetEntity, door, false, false)
        end
    end
end

local function stopDragCam()
    if not cameraState.running then return end

    cameraState.running = false
    RenderScriptCams(false, true, 0, true, false)

    if cameraState.cam then
        DestroyCam(cameraState.cam, true)
        cameraState.cam = nil
    end

    SetCamViewModeForContext(1, 1)
    releaseScaleform()
    cameraState.targetEntity = nil
    cameraState.isFirstPersonView = false
end

local function startInputLoop()
    setCamPosition()

    CreateThread(function()
        local rotating = false

        while cameraState.running do
            if not isTargetValid() then
                stopDragCam()
                break
            end

            DisableControlAction(0, 0, true)
            disableControls(PLAYER_CONTROL_BLOCKS)

            if not cameraState.isFirstPersonView then
                SetMouseCursorActiveThisFrame()
                disableControls(CAMERA_CONTROL_BLOCKS)

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
                cameraState.radius = math.min(cameraState.radius + cameraState.scrollIncrement, cameraState.radiusMax)
                setCamPosition()
            elseif IsDisabledControlJustReleased(0, 15) or IsControlJustReleased(0, 15) then
                cameraState.radius = math.max(cameraState.radius - cameraState.scrollIncrement, cameraState.radiusMin)
                setCamPosition()
            end

            if IsControlJustPressed(0, 22) then
                toggleVehicleDoors()
            end

            if IsDisabledControlJustPressed(0, 0) then
                cameraState.isFirstPersonView = not cameraState.isFirstPersonView
                if cameraState.isFirstPersonView then
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
    if cameraState.running then
        stopDragCam()
    end

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    cameraState.running = true
    cameraState.targetEntity = entity
    cameraState.radius = radiusOptions?.initial or 5.0
    cameraState.radiusMin = radiusOptions?.min or 2.5
    cameraState.radiusMax = radiusOptions?.max or 10.0
    cameraState.scrollIncrement = radiusOptions?.scrollIncrements or 0.5
    cameraState.angleY = 0.0
    cameraState.angleZ = 0.0
    cameraState.isFirstPersonView = false
    cameraState.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    RenderScriptCams(true, true, 0, true, false)
    showInstructionalButtons()
    startInputLoop()
    return true
end

return {
    startDragCam = startDragCam,
    stopDragCam = stopDragCam,
}
