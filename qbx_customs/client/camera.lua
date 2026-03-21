local clientConfig = require 'config.client'

local camera = {}

local state = {
    cam = nil,
    entity = 0,
    active = false,
    yaw = 90.0,
    pitch = 8.0,
    radius = clientConfig.camera.radius,
    firstPerson = false,
}

local CAMERA_BLOCKS = { 1, 2, 3, 4, 5, 6, 24, 25, 69, 70, 92, 140, 141, 142, 143, 257, 263, 264 }

local function disableControls()
    for i = 1, #CAMERA_BLOCKS do
        DisableControlAction(0, CAMERA_BLOCKS[i], true)
    end
end

local function isValid()
    return state.active and state.entity ~= 0 and DoesEntityExist(state.entity)
end

local function release()
    if state.cam then
        DestroyCam(state.cam, false)
        state.cam = nil
    end
    RenderScriptCams(false, true, 200, true, false)
    state.entity = 0
    state.firstPerson = false
    state.active = false
end

local function updatePosition()
    if not isValid() or not state.cam then
        return false
    end

    local entityCoords = GetEntityCoords(state.entity)
    local focus = entityCoords + clientConfig.camera.focusOffset
    local yawRad = math.rad(state.yaw)
    local pitchRad = math.rad(state.pitch)
    local cosPitch = math.cos(pitchRad)
    local camCoords = vec3(
        focus.x + math.cos(yawRad) * cosPitch * state.radius,
        focus.y + math.sin(yawRad) * cosPitch * state.radius,
        focus.z + math.sin(pitchRad) * state.radius
    )

    SetCamCoord(state.cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(state.cam, focus.x, focus.y, focus.z)
    return true
end

function camera.stop()
    release()
end

function camera.start(entity)
    camera.stop()

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    state.active = true
    state.entity = entity
    state.radius = clientConfig.camera.radius
    state.pitch = 8.0
    state.yaw = GetEntityHeading(entity) + 90.0
    state.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)

    updatePosition()
    RenderScriptCams(true, true, 200, true, false)

    CreateThread(function()
        while state.active do
            if not isValid() then
                camera.stop()
                break
            end

            disableControls()

            local lookX = GetDisabledControlNormal(0, 1)
            local lookY = GetDisabledControlNormal(0, 2)
            if math.abs(lookX) > 0.001 or math.abs(lookY) > 0.001 then
                state.yaw = state.yaw - (lookX * 7.5)
                state.pitch = math.min(clientConfig.camera.pitchMax, math.max(clientConfig.camera.pitchMin, state.pitch + (lookY * 7.5)))
                updatePosition()
            end

            if IsDisabledControlJustPressed(0, 241) or IsControlJustPressed(0, 241) then
                state.radius = math.max(clientConfig.camera.minRadius, state.radius - clientConfig.camera.scrollStep)
                updatePosition()
            elseif IsDisabledControlJustPressed(0, 242) or IsControlJustPressed(0, 242) then
                state.radius = math.min(clientConfig.camera.maxRadius, state.radius + clientConfig.camera.scrollStep)
                updatePosition()
            end

            if IsControlJustPressed(0, 22) then
                local doorCount = GetNumberOfVehicleDoors(state.entity) - 1
                for door = 0, doorCount do
                    if GetVehicleDoorAngleRatio(state.entity, door) > 0.0 then
                        SetVehicleDoorShut(state.entity, door, false)
                    else
                        SetVehicleDoorOpen(state.entity, door, false, false)
                    end
                end
            end

            Wait(0)
        end
    end)

    return true
end

return camera
