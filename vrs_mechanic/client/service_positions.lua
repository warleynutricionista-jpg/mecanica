-- ============================================================
-- VRS_MECHANIC - POSICIONAMENTO CONTEXTUAL DE SERVIÇO
-- ============================================================

local function cloneContext(context)
    local copy = {}
    for key, value in pairs(context or {}) do
        copy[key] = value
    end
    return copy
end

local function getServicePositionTolerance(context)
    if context and context.positionTolerance then
        return context.positionTolerance
    end

    return 1.6
end

local wheelPresets = {
    [0] = { bone = 'wheel_lf', door = 'front_left', fallback = vec3(-1.05, 1.35, 0.0), heading = 90.0, label = 'roda dianteira esquerda' },
    [1] = { bone = 'wheel_rf', door = 'front_right', fallback = vec3(1.05, 1.35, 0.0), heading = -90.0, label = 'roda dianteira direita' },
    [2] = { bone = 'wheel_lr', door = 'rear_left', fallback = vec3(-1.05, -1.25, 0.0), heading = 90.0, label = 'roda traseira esquerda' },
    [3] = { bone = 'wheel_rr', door = 'rear_right', fallback = vec3(1.05, -1.25, 0.0), heading = -90.0, label = 'roda traseira direita' },
}

local function getWheelWorldPosition(vehicle, wheelIndex)
    local wheel = wheelPresets[wheelIndex]
    if not wheel then return nil end

    local boneIndex = GetEntityBoneIndexByName(vehicle, wheel.bone)
    if boneIndex and boneIndex ~= -1 then
        local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        return coords, wheel.heading, wheel
    end

    local fallback = GetOffsetFromEntityInWorldCoords(vehicle, wheel.fallback.x, wheel.fallback.y, wheel.fallback.z)
    return fallback, wheel.heading, wheel
end

local function getNearestWheel(vehicle)
    local pedCoords = GetEntityCoords(cache.ped)
    local bestIndex, bestDist = 0, 999.0

    for wheelIndex = 0, 3 do
        local coords = getWheelWorldPosition(vehicle, wheelIndex)
        if coords then
            local dist = #(pedCoords - coords)
            if dist < bestDist then
                bestIndex = wheelIndex
                bestDist = dist
            end
        end
    end

    return bestIndex
end

function VRS.GetServiceContext(serviceType, serviceKey, extra)
    local root = Config.ServiceContexts and Config.ServiceContexts[serviceType]
    local base = root and root[serviceKey]
    if not base then return nil end

    local context = cloneContext(base)
    extra = extra or {}

    if extra.tyreIndex ~= nil then
        context.wheelIndex = extra.tyreIndex
        local wheel = wheelPresets[extra.tyreIndex]
        if wheel then
            context.requiresDoorOpen = wheel.door
            context.serviceLabel = wheel.label
        end
    end

    return context
end

function VRS.GetLiftStateForVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local netId = VRS.GetSafeNetId and select(1, VRS.GetSafeNetId(vehicle)) or nil
    if not netId then
        return nil
    end
    for liftKey, state in pairs(VRS.LiftState or {}) do
        if state and state.vehicleNetId == netId then
            return state, liftKey
        end
    end

    return nil
end

function VRS.GetLiftHeightForVehicle(vehicle)
    local state = VRS.GetLiftStateForVehicle(vehicle)
    return state and (state.height or 0.0) or nil
end

function VRS.GetServiceAccessMessage(context)
    if not context then return nil end

    if context.requiresLift then
        return ('Este serviço exige o elevador acima de %.2fm.'):format(context.minimumLiftHeight or 0.0)
    end

    if context.serviceArea == 'wheel' then
        return ('O serviço será executado na %s.'):format(context.serviceLabel or 'roda selecionada')
    end

    if context.requiresHoodOpen then
        return 'O serviço será executado na parte frontal com o capô aberto.'
    end

    if context.requiresDoorOpen then
        return 'O serviço será executado na lateral correta do veículo.'
    end

    return nil
end

function VRS.GetServicePosition(vehicle, context)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not context then return nil end

    local preset = context.positionPreset
    if preset == 'nearest_wheel' then
        context.wheelIndex = getNearestWheel(vehicle)
        preset = 'specific_wheel'
    elseif preset == 'nearest_side' then
        local pedCoords = GetEntityCoords(cache.ped)
        local leftCoords = GetOffsetFromEntityInWorldCoords(vehicle, -1.6, 0.2, 0.0)
        local rightCoords = GetOffsetFromEntityInWorldCoords(vehicle, 1.6, 0.2, 0.0)
        local useLeft = #(pedCoords - leftCoords) <= #(pedCoords - rightCoords)
        context.requiresDoorOpen = context.requiresDoorOpen or (useLeft and 'front_left' or 'front_right')
        preset = useLeft and 'left_side' or 'right_side'
    elseif preset == 'underbody_side' then
        local pedCoords = GetEntityCoords(cache.ped)
        local leftCoords = GetOffsetFromEntityInWorldCoords(vehicle, -0.9, 0.15, 0.0)
        local rightCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.9, 0.15, 0.0)
        local useLeft = #(pedCoords - leftCoords) <= #(pedCoords - rightCoords)
        preset = useLeft and 'underbody_left' or 'underbody_right'
    end

    if preset == 'specific_wheel' then
        local wheelIndex = context.wheelIndex or getNearestWheel(vehicle)
        local coords, heading, wheel = getWheelWorldPosition(vehicle, wheelIndex)
        if wheel then
            context.requiresDoorOpen = context.requiresDoorOpen or wheel.door
            context.serviceLabel = context.serviceLabel or wheel.label
        end
        return coords, heading or 0.0, context
    end

    local config = Config.ServicePositionPresets[preset]
    if not config then return nil end

    local coords = GetOffsetFromEntityInWorldCoords(vehicle, config.offset.x, config.offset.y, config.offset.z)
    local heading = GetEntityHeading(vehicle) + (config.heading or 0.0)
    return coords, heading, context
end

function VRS.MovePlayerToServicePosition(vehicle, context)
    local ped = cache.ped
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local coords, heading = VRS.GetServicePosition(vehicle, context)
    if not coords then
        lib.notify({ title = 'Serviço', description = 'Não foi possível calcular a posição correta do mecânico.', type = 'error' })
        return false
    end

    if #(GetEntityCoords(ped) - coords) > getServicePositionTolerance(context) then
        lib.notify({
            title = 'Serviço',
            description = 'Posicione-se corretamente para iniciar o reparo.',
            type = 'error',
        })
        return false
    end

    SetEntityHeading(ped, heading or GetEntityHeading(ped))
    return true
end

function VRS.EnsureServiceReadiness(vehicle, context)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Serviço', description = 'Entidade de veículo inválida para este serviço.', type = 'error' })
        return false
    end

    if GetEntitySpeed(vehicle) > 0.5 then
        lib.notify({ title = 'Serviço', description = 'Não é possível trabalhar com o veículo em movimento.', type = 'error' })
        return false
    end

    if context and context.requiresLift then
        local currentHeight = VRS.GetLiftHeightForVehicle(vehicle)
        if not currentHeight then
            lib.notify({ title = 'Serviço', description = 'Este serviço exige o veículo corretamente posicionado no elevador.', type = 'error' })
            return false
        end

        if currentHeight + 0.01 < (context.minimumLiftHeight or 0.0) then
            lib.notify({
                title = 'Serviço',
                description = ('Elevador muito baixo para acessar este componente. Altura mínima: %.2fm.'):format(context.minimumLiftHeight or 0.0),
                type = 'error',
            })
            return false
        end
    end

    return true
end

function VRS.BeginContextualVehicleService(vehicle, shopId, serviceType, serviceKey, extra)
    local plate = VRS.GetPlate(vehicle)
    local netId = VRS.GetSafeNetId and select(1, VRS.GetSafeNetId(vehicle)) or nil
    local context = VRS.GetServiceContext(serviceType, serviceKey, extra)
    if not plate or not context then
        lib.notify({ title = 'Serviço', description = 'Configuração contextual inválida para este serviço.', type = 'error' })
        return nil
    end

    if not VRS.EnsureServiceReadiness(vehicle, context) then
        return nil
    end

    local begin = lib.callback.await('vrs_mechanic:server:beginVehicleService', false, serviceType, serviceKey, {
        plate = plate,
        netId = netId,
        shopId = shopId,
    })

    if not begin or not begin.success then
        local reason = begin and begin.reason or 'unknown'
        local messages = {
            lift_required = 'Este reparo exige o veículo corretamente posicionado no elevador.',
            lift_too_low = 'Este reparo exige o elevador acima da altura mínima.',
            service_busy = 'Outro mecânico já está executando este serviço crítico.',
            vehicle_moving = 'Não é possível executar o serviço com o veículo em movimento.',
            invalid_vehicle = 'O contexto do veículo ficou inválido durante a preparação.',
        }
        lib.notify({ title = 'Serviço', description = messages[reason] or 'Não foi possível iniciar o serviço contextual.', type = 'error' })
        return nil
    end

    local infoMessage = VRS.GetServiceAccessMessage(context)
    if infoMessage then
        lib.notify({ title = 'Serviço', description = infoMessage, type = 'inform' })
    end

    VRS.OpenVehicleAccess(vehicle, context)

    if not VRS.MovePlayerToServicePosition(vehicle, context) then
        VRS.CloseVehicleAccess(vehicle, context)
        lib.callback.await('vrs_mechanic:server:endVehicleService', false, begin.lockKey)
        return nil
    end

    return {
        context = context,
        lockKey = begin.lockKey,
        plate = plate,
        netId = netId,
    }
end

function VRS.FinishContextualVehicleService(vehicle, serviceState)
    if not serviceState then return end

    if serviceState.context then
        VRS.CloseVehicleAccess(vehicle, serviceState.context)
    end

    if serviceState.lockKey then
        lib.callback.await('vrs_mechanic:server:endVehicleService', false, serviceState.lockKey)
    end
end
