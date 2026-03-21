Paintjob = Paintjob or {}
Paintjob.Effects = Paintjob.Effects or {}

local Utils = Paintjob.Utils
local Effects = Paintjob.Effects

Effects.sprayProps = {}
Effects.active = {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(25)
    end

    return hash
end

local function loadPtfx(dict)
    if HasNamedPtfxAssetLoaded(dict) then return true end
    RequestNamedPtfxAsset(dict)
    local expiresAt = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < expiresAt do
        Wait(25)
    end
    return HasNamedPtfxAssetLoaded(dict)
end

local function stopHandle(handle)
    if handle and handle ~= -1 then
        StopParticleFxLooped(handle, false)
    end
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getSpraySourceCoords(spray, object)
    if object and DoesEntityExist(object) then
        return GetOffsetFromEntityInWorldCoords(object, 0.18, 0.0, 0.08)
    end

    return Utils.toVec3(spray and spray.pos)
end

local function getVehicleTargetCoords(vehicle, sourceCoords, fallback)
    local origin = Utils.toVec3(sourceCoords)
    if not origin or not Utils.isValidVehicle(vehicle) then
        return Utils.toVec3(fallback)
    end

    local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    local relative = GetOffsetFromEntityGivenWorldCoords(vehicle, origin.x, origin.y, origin.z)

    local targetX = clamp(relative.x, minDim.x + 0.15, maxDim.x - 0.15)
    local targetY = relative.y >= 0.0 and (maxDim.y - 0.02) or (minDim.y + 0.02)
    local targetZ = clamp(relative.z, minDim.z + 0.35, maxDim.z - 0.12)

    return GetOffsetFromEntityInWorldCoords(vehicle, targetX, targetY, targetZ)
end

local function calculateSprayRotation(fromCoords, targetCoords, fallback)
    local origin = Utils.toVec3(fromCoords)
    local target = Utils.toVec3(targetCoords)
    if not origin or not target then
        return Utils.toVec3(fallback) or vec3(0.0, 0.0, 0.0)
    end

    local delta = target - origin
    local distance2d = math.sqrt((delta.x * delta.x) + (delta.y * delta.y))
    if distance2d <= 0.001 and math.abs(delta.z) <= 0.001 then
        return Utils.toVec3(fallback) or vec3(0.0, 0.0, 0.0)
    end

    local pitch = math.deg(math.atan2(-delta.z, math.max(distance2d, 0.001)))
    local yaw = math.deg(math.atan2(delta.y, delta.x))
    return vec3(0.0, pitch, yaw)
end

function Effects.spawnSprayProps()
    local modelHash = loadModel(Config.SprayModel)
    if not modelHash then
        Utils.debug('Spray model inválido', { model = Config.SprayModel })
        return
    end

    for boothId, booth in ipairs(Config.Locations or {}) do
        Effects.sprayProps[boothId] = Effects.sprayProps[boothId] or {}
        for sprayIndex, spray in ipairs(booth.sprays or {}) do
            local pos = Utils.toVec3(spray.pos)
            local rot = Utils.toVec3(spray.rotation) or vec3(0.0, 0.0, 0.0)
            if pos then
                local object = CreateObjectNoOffset(modelHash, pos.x, pos.y, pos.z, false, false, false)
                SetEntityRotation(object, rot.x, rot.y, rot.z, 2, true)
                FreezeEntityPosition(object, true)
                SetEntityCollision(object, false, false)
                SetEntityAsMissionEntity(object, true, true)
                Effects.sprayProps[boothId][sprayIndex] = object
            end
        end
    end

    SetModelAsNoLongerNeeded(modelHash)
end

function Effects.stopBooth(boothId)
    local active = Effects.active[boothId]
    if not active then return end

    for _, handle in ipairs(active.handles or {}) do
        stopHandle(handle)
    end

    if active.finishSmoke and active.finishSmoke ~= -1 then
        stopHandle(active.finishSmoke)
    end

    Effects.active[boothId] = nil
end

function Effects.startBooth(boothId, vehicle, color)
    Effects.stopBooth(boothId)

    local booth = Utils.getBooth(boothId)
    if not booth then return end

    local sprayFx = Config.Particles.Spray
    if not loadPtfx(sprayFx.dict) then return end

    Effects.active[boothId] = { handles = {} }

    for sprayIndex, spray in ipairs(booth.sprays or {}) do
        local object = Effects.sprayProps[boothId] and Effects.sprayProps[boothId][sprayIndex]
        if object and DoesEntityExist(object) then
            local sourceCoords = getSpraySourceCoords(spray, object)
            local targetCoords = getVehicleTargetCoords(vehicle, sourceCoords, booth.vehicle)
            local rot = calculateSprayRotation(sourceCoords, targetCoords, spray.rotation)
            UseParticleFxAsset(sprayFx.dict)
            local handle = StartParticleFxLoopedAtCoord(
                sprayFx.name,
                sourceCoords.x, sourceCoords.y, sourceCoords.z,
                rot.x, rot.y, rot.z,
                spray.scale or sprayFx.scale or 1.0,
                false, false, false, false
            )

            if handle and handle ~= -1 then
                local rgb = color or { r = 255, g = 255, b = 255 }
                SetParticleFxLoopedColour(handle, rgb.r / 255.0, rgb.g / 255.0, rgb.b / 255.0, false)
                SetParticleFxLoopedAlpha(handle, sprayFx.alpha or 0.85)
                Effects.active[boothId].handles[#Effects.active[boothId].handles + 1] = handle
            end
        end
    end

    if Utils.isValidVehicle(vehicle) then
        local smokeFx = Config.Particles.FinishSmoke
        if loadPtfx(smokeFx.dict) then
            UseParticleFxAsset(smokeFx.dict)
            local smokeHandle = StartParticleFxLoopedOnEntity(
                smokeFx.name,
                vehicle,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                smokeFx.scale or 0.8,
                false, false, false
            )
            Effects.active[boothId].finishSmoke = smokeHandle
        end
    end
end

function Effects.cleanupAll()
    for boothId in pairs(Effects.active) do
        Effects.stopBooth(boothId)
    end

    for boothId, props in pairs(Effects.sprayProps) do
        for index, object in pairs(props) do
            if object and DoesEntityExist(object) then
                DeleteObject(object)
            end
            Effects.sprayProps[boothId][index] = nil
        end
    end
end
