Paintjob = Paintjob or {}
Paintjob.Utils = Paintjob.Utils or {}

local Utils = Paintjob.Utils

local finishByValue = {}
for _, finish in ipairs(Config.FinishTypes or {}) do
    finishByValue[finish.value] = finish
end

function Utils.debug(message, payload)
    if not Config.Debug then return end
    print(('[mri_Qpaintjob] %s'):format(message))
    if payload then
        print(json.encode(payload))
    end
end

function Utils.toVec3(value)
    if not value then return nil end
    local x = value.x or value[1]
    local y = value.y or value[2]
    local z = value.z or value[3]
    if not x or not y or not z then return nil end
    return vec3(x + 0.0, y + 0.0, z + 0.0)
end

function Utils.distance(a, b)
    local av, bv = Utils.toVec3(a), Utils.toVec3(b)
    if not av or not bv then return math.huge end
    return #(av - bv)
end

function Utils.getBooth(boothId)
    local booth = Config.Locations and Config.Locations[boothId]
    if not booth or not booth.control or not booth.vehicle then
        return nil
    end
    return booth
end

function Utils.getBoothName(boothId)
    local booth = Utils.getBooth(boothId)
    return booth and booth.name or ('Cabine #%s'):format(boothId)
end

function Utils.getControlRadius(booth)
    booth = booth or {}
    return booth.radius and booth.radius.control or Config.DefaultControlRadius
end

function Utils.getVehicleRadius(booth)
    booth = booth or {}
    return booth.radius and booth.radius.vehicle or Config.DefaultVehicleRadius
end

function Utils.hasJobAccess(booth)
    local jobs = booth.jobs
    if jobs == false then return true end
    if not jobs or #jobs == 0 then jobs = Config.AllowedJobsFallback end
    if not jobs or #jobs == 0 then return true end

    local stateJob = LocalPlayer and LocalPlayer.state and LocalPlayer.state.job
    local jobName = type(stateJob) == 'table' and stateJob.name or stateJob
    if not jobName then return true end

    for _, allowedJob in ipairs(jobs) do
        if allowedJob == jobName then
            return true
        end
    end

    return false
end

function Utils.notify(data)
    lib.notify({
        title = data.title or Config.UI.Title,
        description = data.description,
        type = data.type or 'inform',
        position = Config.UI.Position,
    })
end

function Utils.hexToRgb(hex)
    if type(hex) ~= 'string' then return { r = 255, g = 255, b = 255 } end
    local sanitized = hex:gsub('#', '')
    if #sanitized ~= 6 then return { r = 255, g = 255, b = 255 } end
    return {
        r = tonumber(sanitized:sub(1, 2), 16) or 255,
        g = tonumber(sanitized:sub(3, 4), 16) or 255,
        b = tonumber(sanitized:sub(5, 6), 16) or 255,
    }
end

function Utils.rgbToHex(rgb)
    local r = math.min(255, math.max(0, math.floor((rgb.r or 255) + 0.5)))
    local g = math.min(255, math.max(0, math.floor((rgb.g or 255) + 0.5)))
    local b = math.min(255, math.max(0, math.floor((rgb.b or 255) + 0.5)))
    return ('#%02X%02X%02X'):format(r, g, b)
end

function Utils.isValidVehicle(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle)
end

function Utils.getSafeNetId(vehicle)
    if not Utils.isValidVehicle(vehicle) then return nil, 'invalid_vehicle' end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return nil, 'invalid_network_id' end
    return netId
end

function Utils.requestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    timeout = timeout or 1500

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    local expiresAt = GetGameTimer() + timeout
    NetworkRequestControlOfEntity(entity)

    while GetGameTimer() < expiresAt do
        if NetworkHasControlOfEntity(entity) then
            return true
        end
        Wait(25)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

function Utils.getVehicleDisplayName(vehicle)
    if not Utils.isValidVehicle(vehicle) then return 'Veículo inválido' end
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(displayName)
    if not label or label == 'NULL' then
        label = displayName
    end
    local plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' then plate = 'Sem placa' end
    return ('%s • %s'):format(label, plate)
end

function Utils.findVehicleInBooth(boothId)
    local booth = Utils.getBooth(boothId)
    if not booth then return nil, 'invalid_booth' end

    local vehicleCoords = Utils.toVec3(booth.vehicle)
    if not vehicleCoords then return nil, 'invalid_vehicle_coords' end

    local radius = Utils.getVehicleRadius(booth)
    local vehicle = GetClosestVehicle(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, radius + 1.5, 0, 71)
    if not Utils.isValidVehicle(vehicle) then
        return nil, 'vehicle_not_found'
    end

    local distance = Utils.distance(GetEntityCoords(vehicle), vehicleCoords)
    if distance > radius then
        return nil, 'vehicle_outside_booth'
    end

    return vehicle
end

function Utils.getVehiclePaintState(vehicle)
    if not Utils.isValidVehicle(vehicle) then return nil end

    local primaryType, primaryColor, pearl = GetVehicleModColor_1(vehicle)
    local secondaryType, secondaryColor = GetVehicleModColor_2(vehicle)
    local wheelColor
    local _, currentWheelColor = GetVehicleExtraColours(vehicle)
    wheelColor = currentWheelColor

    local pr, pg, pb = GetVehicleCustomPrimaryColour(vehicle)
    local sr, sg, sb = GetVehicleCustomSecondaryColour(vehicle)

    return {
        primary = { r = pr, g = pg, b = pb },
        secondary = { r = sr, g = sg, b = sb },
        finish = tonumber(primaryType) or 0,
        primaryColorIndex = tonumber(primaryColor) or 0,
        secondaryColorIndex = tonumber(secondaryColor) or 0,
        pearlescentColor = tonumber(pearl) or 0,
        wheelColor = tonumber(wheelColor) or 0,
        secondaryFinish = tonumber(secondaryType) or tonumber(primaryType) or 0,
    }
end

function Utils.getFinishByValue(value)
    return finishByValue[tonumber(value) or 0] or finishByValue[0]
end

function Utils.applyPaintState(vehicle, state)
    if not Utils.isValidVehicle(vehicle) or not state then return false end

    local finish = tonumber(state.finish) or 0
    local pearlescent = tonumber(state.pearlescentColor) or 0
    local wheelColor = tonumber(state.wheelColor) or 0
    local secondaryFinish = tonumber(state.secondaryFinish) or finish
    local primaryColorIndex = tonumber(state.primaryColorIndex) or 0
    local secondaryColorIndex = tonumber(state.secondaryColorIndex) or 0

    SetVehicleModColor_1(vehicle, finish, primaryColorIndex, pearlescent)
    SetVehicleModColor_2(vehicle, secondaryFinish, secondaryColorIndex)
    SetVehicleCustomPrimaryColour(vehicle, state.primary.r, state.primary.g, state.primary.b)
    SetVehicleCustomSecondaryColour(vehicle, state.secondary.r, state.secondary.g, state.secondary.b)
    SetVehicleExtraColours(vehicle, pearlescent, wheelColor)

    return true
end

function Utils.lerpColor(from, target, progress)
    local function lerp(a, b, t)
        return math.floor(a + ((b - a) * t) + 0.5)
    end

    return {
        r = lerp(from.r or 0, target.r or 0, progress),
        g = lerp(from.g or 0, target.g or 0, progress),
        b = lerp(from.b or 0, target.b or 0, progress),
    }
end
