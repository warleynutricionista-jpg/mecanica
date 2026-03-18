-- ============================================================
-- VRS_MECHANIC - CONTROLE DE ELEVADOR
-- ============================================================

local activeLiftAnimations = {}

local ACTION_MESSAGES = {
    up = 'Elevador subindo.',
    down = 'Elevador descendo.',
    save_current = 'Altura atual salva com sucesso.',
    go_saved = 'Elevador indo para a altura salva.',
    reset_height = 'Elevador retornando para a posição inicial.',
    reset_saved = 'Altura salva resetada com sucesso.',
}

local ERROR_MESSAGES = {
    lift_empty = 'Não há veículo corretamente posicionado no elevador.',
    lift_occupied = 'Elevador ocupado.',
    already_top = 'O elevador já está na altura máxima.',
    already_bottom = 'O elevador já está na posição mínima.',
    no_access = 'Você não tem permissão para usar este elevador.',
    not_on_duty = 'Você precisa estar em serviço para usar este elevador.',
    invalid_height = 'Altura inválida para este elevador.',
    invalid_lift = 'Elevador inválido.',
    lift_busy = 'Aguarde o elevador concluir o movimento atual.',
    no_saved_height = 'Não há altura salva para este elevador.',
    saved_height_missing = 'Não há altura salva para este elevador.',
    same_height = 'O elevador já está nessa altura.',
    lift_not_lowered = 'Abaixe totalmente o elevador antes de retirar o veículo.',
    invalid_vehicle = 'Não foi possível identificar o veículo no elevador.',
    too_far = 'Aproxime-se do painel do elevador para utilizar este comando.',
}

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function roundHeight(value)
    return tonumber(('%0.2f'):format(value or 0.0)) or 0.0
end

local function cloneTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local cloned = {}
    for key, data in pairs(value) do
        cloned[key] = data
    end
    return cloned
end

local function requestControl(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1000

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function stopLiftAnimation(liftKey)
    local animation = activeLiftAnimations[liftKey]
    if animation then
        animation.cancelled = true
        activeLiftAnimations[liftKey] = nil
    end
end

local function getMoveDuration(fromHeight, toHeight)
    local distance = math.abs((toHeight or 0.0) - (fromHeight or 0.0))
    if distance <= 0.001 then
        return 0
    end

    local speed = Config.Lift.MoveSpeed or 0.18
    local duration = math.floor((distance / math.max(speed, 0.01)) * 1000)
    return math.max(duration, Config.Lift.minMoveDuration or 900)
end

local function animateLiftVehicle(shopId, liftIndex, vehicle, fromHeight, toHeight, state)
    local liftKey = getLiftKey(shopId, liftIndex)
    stopLiftAnimation(liftKey)

    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local targetCoords, heading = VRS.GetLiftWorldCoords(shopId, liftIndex, toHeight)
    if not targetCoords then return end

    local startCoords = GetEntityCoords(vehicle)
    local currentCoords = VRS.GetLiftWorldCoords(shopId, liftIndex, fromHeight)
    if currentCoords then
        startCoords = vec3(currentCoords.x, currentCoords.y, currentCoords.z)
    end

    requestControl(vehicle)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)

    local duration = getMoveDuration(fromHeight, toHeight)
    if duration <= 0 then
        SetEntityCoordsNoOffset(vehicle, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
        SetEntityHeading(vehicle, heading)
        return
    end

    local animation = {
        cancelled = false,
        targetHeight = roundHeight(toHeight),
    }
    activeLiftAnimations[liftKey] = animation

    CreateThread(function()
        local startTime = GetGameTimer()
        while not animation.cancelled do
            if vehicle == 0 or not DoesEntityExist(vehicle) then
                break
            end

            local progress = math.min((GetGameTimer() - startTime) / duration, 1.0)
            local eased = progress < 1.0 and (1.0 - ((1.0 - progress) * (1.0 - progress))) or 1.0
            local nextZ = startCoords.z + ((targetCoords.z - startCoords.z) * eased)

            requestControl(vehicle)
            SetEntityCoordsNoOffset(vehicle, targetCoords.x, targetCoords.y, nextZ, false, false, false)
            SetEntityHeading(vehicle, heading)

            if progress >= 1.0 then
                break
            end

            Wait(0)
        end

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            requestControl(vehicle)
            SetEntityCoordsNoOffset(vehicle, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
            SetEntityHeading(vehicle, heading)
            FreezeEntityPosition(vehicle, true)
            SetVehicleEngineOn(vehicle, false, true, true)
        end

        activeLiftAnimations[liftKey] = nil
        VRS.LiftState[liftKey] = VRS.LiftState[liftKey] or {}
        VRS.LiftState[liftKey].height = roundHeight(toHeight)
        VRS.LiftState[liftKey].busy = state and state.busy or false
    end)
end

local function notifyLiftError(reason)
    lib.notify({
        title = 'Elevador',
        description = ERROR_MESSAGES[reason] or 'Não foi possível concluir a ação no elevador.',
        type = 'error',
    })
end

function VRS.GetLiftKey(shopId, liftIndex)
    return getLiftKey(shopId, liftIndex)
end

function VRS.GetLiftBaseCoords(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    local lift = shop and shop.lifts and shop.lifts[liftIndex]
    if not lift then return nil end

    return vec3(lift.coords.x, lift.coords.y, lift.coords.z), lift.coords.w or 0.0
end

function VRS.GetLiftHeightLabel(height)
    height = roundHeight(height)
    local presets = Config.Lift.DefaultWorkHeights or {}

    if math.abs(height - (Config.Lift.MinHeight or 0.0)) <= 0.05 then
        return 'Base'
    end
    if presets.engine and math.abs(height - presets.engine) <= 0.08 then
        return 'Serviço do motor'
    end
    if presets.wheel and math.abs(height - presets.wheel) <= 0.08 then
        return 'Serviço de roda/freio'
    end
    if presets.underbody and math.abs(height - presets.underbody) <= 0.08 then
        return 'Serviço inferior'
    end

    return ('%.2fm'):format(height)
end

function VRS.GetLiftWorldCoords(shopId, liftIndex, height)
    local baseCoords, heading = VRS.GetLiftBaseCoords(shopId, liftIndex)
    if not baseCoords then return nil end

    local clampedHeight = math.min(math.max(roundHeight(height), Config.Lift.MinHeight or 0.0), Config.Lift.MaxHeight or 1.2)
    return vec3(baseCoords.x, baseCoords.y, baseCoords.z + clampedHeight), heading
end

function VRS.CanUseLift(shopId)
    local shop = Config.Shops[shopId]
    if not shop then return false end

    if shop.type ~= 'owned' then
        return true
    end

    if shop.job and not VRS.IsMechanic() then
        return false
    end

    if Config.ShopRepair.requireDuty and not VRS.IsOnDuty() then
        return false
    end

    return true
end

function VRS.ApplyLiftState(shopId, liftIndex, state)
    if not state then return end

    local liftKey = getLiftKey(shopId, liftIndex)
    local previousState = VRS.LiftState[liftKey] or {}
    local mergedState = cloneTable(state)

    if previousState.savedHeight ~= nil and mergedState.savedHeight == nil then
        mergedState.savedHeight = previousState.savedHeight
    end

    VRS.LiftState[liftKey] = mergedState
    VRS.OnLift[liftKey] = mergedState.vehicleNetId

    if previousState.vehicleNetId and previousState.vehicleNetId ~= mergedState.vehicleNetId then
        local previousVehicle = NetworkGetEntityFromNetworkId(previousState.vehicleNetId)
        if previousVehicle ~= 0 and DoesEntityExist(previousVehicle) then
            requestControl(previousVehicle)
            FreezeEntityPosition(previousVehicle, false)
        end
    end

    if not mergedState.vehicleNetId then
        stopLiftAnimation(liftKey)
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(mergedState.vehicleNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local fromHeight = previousState.height or Config.Lift.MinHeight or 0.0
    local toHeight = mergedState.height or Config.Lift.MinHeight or 0.0
    local shouldAnimate = math.abs((toHeight or 0.0) - (fromHeight or 0.0)) > (Config.Lift.positionTolerance or 0.02)

    if shouldAnimate and mergedState.busy then
        animateLiftVehicle(shopId, liftIndex, vehicle, fromHeight, toHeight, mergedState)
        return
    end

    stopLiftAnimation(liftKey)
    local coords, heading = VRS.GetLiftWorldCoords(shopId, liftIndex, toHeight)
    if not coords then return end

    requestControl(vehicle)
    SetEntityCoordsNoOffset(vehicle, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(vehicle, heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)
end

RegisterNetEvent('vrs_mechanic:client:syncLiftState', function(shopId, liftIndex, state)
    VRS.ApplyLiftState(shopId, liftIndex, state)
end)

function VRS.RefreshLiftState(shopId, liftIndex)
    local state = lib.callback.await('vrs_mechanic:server:getLiftState', false, shopId, liftIndex)
    if state then
        VRS.ApplyLiftState(shopId, liftIndex, state)
    end
    return state
end

function VRS.UseLiftPanelAction(shopId, liftIndex, action)
    if not VRS.CanUseLift(shopId) then
        notifyLiftError(VRS.IsMechanic() and 'not_on_duty' or 'no_access')
        return false
    end

    local callbacks = {
        up = 'vrs_mechanic:server:moveLiftDirection',
        down = 'vrs_mechanic:server:moveLiftDirection',
        save_current = 'vrs_mechanic:server:saveLiftHeight',
        go_saved = 'vrs_mechanic:server:goToSavedLiftHeight',
        reset_height = 'vrs_mechanic:server:resetLiftHeight',
        reset_saved = 'vrs_mechanic:server:resetSavedLiftHeight',
    }

    local callbackName = callbacks[action]
    if not callbackName then
        return false
    end

    local result
    if action == 'up' or action == 'down' then
        result = lib.callback.await(callbackName, false, shopId, liftIndex, action)
    else
        result = lib.callback.await(callbackName, false, shopId, liftIndex)
    end

    if not result or not result.success then
        notifyLiftError(result and result.reason or 'unknown')
        return false
    end

    if result.state then
        VRS.ApplyLiftState(shopId, liftIndex, result.state)
    end

    if result.savedHeight ~= nil then
        local liftKey = getLiftKey(shopId, liftIndex)
        VRS.LiftState[liftKey] = VRS.LiftState[liftKey] or {}
        VRS.LiftState[liftKey].savedHeight = result.savedHeight
    end

    lib.notify({
        title = 'Elevador',
        description = result.message or ACTION_MESSAGES[action] or 'Ação concluída com sucesso.',
        type = 'success',
    })

    return true, result.state
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for liftKey in pairs(activeLiftAnimations) do
        stopLiftAnimation(liftKey)
    end
end)
