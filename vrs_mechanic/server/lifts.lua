-- ============================================================
-- VRS_MECHANIC - LIFTS SERVER
-- ============================================================

VRS.LiftStates = VRS.LiftStates or {}

local presetFile = Config.Lift.savedPresetFile or 'lift_presets.json'
local savedLiftHeights = {}

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


local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function getPresetKey(source, shopId, liftIndex)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    return ('%s:%s:%s'):format(player.PlayerData.citizenid, shopId, liftIndex)
end

local function loadSavedHeights()
    local resourceName = GetCurrentResourceName()
    local raw = LoadResourceFile(resourceName, presetFile)
    if not raw or raw == '' then
        savedLiftHeights = {}
        return
    end

    local decoded = json.decode(raw)
    savedLiftHeights = type(decoded) == 'table' and decoded or {}
end

local function persistSavedHeights()
    SaveResourceFile(GetCurrentResourceName(), presetFile, json.encode(savedLiftHeights), -1)
end

local function clampHeight(height)
    local numericHeight = tonumber(height)
    if not numericHeight then return nil end
    return VRS.Clamp(numericHeight, Config.Lift.MinHeight or 0.0, Config.Lift.MaxHeight or 1.2)
end

local function getLegacyLevelFromHeight(height)
    local levels = Config.Lift.levels or {}
    local bestIndex, bestDelta = 1, math.huge
    for index, level in ipairs(levels) do
        local delta = math.abs((level.zOffset or 0.0) - (height or 0.0))
        if delta < bestDelta then
            bestIndex = index
            bestDelta = delta
        end
    end
    return bestIndex
end

local function buildLiftState(shopId, liftIndex)
    local key = getLiftKey(shopId, liftIndex)
    local state = VRS.LiftStates[key] or {
        shopId = shopId,
        liftIndex = liftIndex,
        height = Config.Lift.MinHeight or 0.0,
        minHeight = Config.Lift.MinHeight or 0.0,
        maxHeight = Config.Lift.MaxHeight or 1.2,
        vehicleNetId = nil,
        plate = nil,
        busy = false,
        targetHeight = Config.Lift.MinHeight or 0.0,
    }

    state.minHeight = Config.Lift.MinHeight or 0.0
    state.maxHeight = Config.Lift.MaxHeight or 1.2
    state.height = clampHeight(state.height) or state.minHeight
    state.targetHeight = clampHeight(state.targetHeight) or state.height
    state.level = getLegacyLevelFromHeight(state.height)

    if state.vehicleNetId and state.vehicleNetId ~= 0 then
        local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            state.vehicleNetId = nil
            state.plate = nil
            state.height = state.minHeight
            state.targetHeight = state.minHeight
            state.busy = false
        end
    end

    return state
end

local function enrichStateForSource(source, state, shopId, liftIndex)
    if not state then return nil end

    local response = cloneTable(state)
    local presetKey = getPresetKey(source, shopId, liftIndex)
    response.savedHeight = presetKey and savedLiftHeights[presetKey] or nil
    return response
end

local function syncLiftState(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    VRS.LiftStates[getLiftKey(shopId, liftIndex)] = state
    TriggerClientEvent('vrs_mechanic:client:syncLiftState', -1, shopId, liftIndex, state)
    return state
end

local function validateLiftAccess(source, shopId, liftIndex)
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts or not shop.lifts[liftIndex] then
        return false, 'invalid_lift'
    end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(source, shopId) then
            return false, 'no_access'
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty(source) then
            return false, 'not_on_duty'
        end
    end

    return true, nil, shop
end

local function getMoveDurationMs(fromHeight, toHeight)
    local distance = math.abs((toHeight or 0.0) - (fromHeight or 0.0))
    if distance <= 0.001 then
        return 0
    end

    local speed = math.max(Config.Lift.MoveSpeed or 0.18, 0.01)
    local duration = math.floor((distance / speed) * 1000)
    return math.max(duration, Config.Lift.minMoveDuration or 900)
end

local function finalizeLiftMovement(shopId, liftIndex, targetHeight)
    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)

    if math.abs((state.targetHeight or 0.0) - (targetHeight or 0.0)) > 0.001 then
        return
    end

    state.height = targetHeight
    state.targetHeight = targetHeight
    state.level = getLegacyLevelFromHeight(targetHeight)
    state.busy = false
    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
end

local function buildActionResponse(source, shopId, liftIndex, state, message)
    local enrichedState = enrichStateForSource(source, state, shopId, liftIndex)
    return {
        success = true,
        state = enrichedState,
        savedHeight = enrichedState and enrichedState.savedHeight or nil,
        message = message,
    }
end

local function setLiftHeightInternal(source, shopId, liftIndex, targetHeight, successMessage)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if state.busy then
        return { success = false, reason = 'lift_busy' }
    end

    local clamped = clampHeight(targetHeight)
    if clamped == nil then
        return { success = false, reason = 'invalid_height' }
    end

    local currentHeight = state.height or (Config.Lift.MinHeight or 0.0)
    local tolerance = Config.Lift.positionTolerance or 0.02

    if clamped > (Config.Lift.MinHeight or 0.0) + tolerance and not state.vehicleNetId and Config.Lift.requireVehicleToRaise then
        return { success = false, reason = 'lift_empty' }
    end

    if math.abs(clamped - currentHeight) <= tolerance then
        if clamped >= (Config.Lift.MaxHeight or 1.2) - tolerance then
            return { success = false, reason = 'already_top' }
        elseif clamped <= (Config.Lift.MinHeight or 0.0) + tolerance then
            return { success = false, reason = 'already_bottom' }
        end

        return { success = false, reason = 'same_height' }
    end

    local moveDuration = getMoveDurationMs(currentHeight, clamped)
    state.height = clamped
    state.targetHeight = clamped
    state.level = getLegacyLevelFromHeight(clamped)
    state.busy = moveDuration > 0
    VRS.LiftStates[key] = state

    local synced = syncLiftState(shopId, liftIndex)

    if moveDuration > 0 then
        SetTimeout(moveDuration, function()
            finalizeLiftMovement(shopId, liftIndex, clamped)
        end)
    end

    return buildActionResponse(source, shopId, liftIndex, synced, successMessage)
end

lib.callback.register('vrs_mechanic:server:getLiftState', function(source, shopId, liftIndex)
    local ok = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return nil
    end

    return enrichStateForSource(source, syncLiftState(shopId, liftIndex), shopId, liftIndex)
end)

lib.callback.register('vrs_mechanic:server:placeVehicleOnLift', function(source, shopId, liftIndex, netId, plate)
    local src = source
    local ok, reason = validateLiftAccess(src, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local validVehicle, _, vehicleReason = VRS.ValidateVehicleContext(src, plate, netId, Config.Lift.maxDistance or 12.0)
    if not validVehicle then
        return { success = false, reason = vehicleReason or 'invalid_vehicle' }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if state.busy then
        return { success = false, reason = 'lift_busy' }
    end

    if state.vehicleNetId and state.vehicleNetId ~= netId then
        return { success = false, reason = 'lift_occupied' }
    end

    state.vehicleNetId = netId
    state.plate = plate
    state.height = Config.Lift.MinHeight or 0.0
    state.targetHeight = state.height
    state.level = getLegacyLevelFromHeight(state.height)
    state.busy = false
    VRS.LiftStates[key] = state

    return buildActionResponse(src, shopId, liftIndex, syncLiftState(shopId, liftIndex), 'Veículo posicionado e pronto para serviço.')
end)

lib.callback.register('vrs_mechanic:server:setLiftHeight', function(source, shopId, liftIndex, targetHeight)
    return setLiftHeightInternal(source, shopId, liftIndex, targetHeight)
end)

lib.callback.register('vrs_mechanic:server:moveLiftDirection', function(source, shopId, liftIndex, direction)
    local state = buildLiftState(shopId, liftIndex)
    local step = Config.Lift.StepHeight or 0.15
    local targetHeight = (state.height or 0.0) + (direction == 'up' and step or -step)
    local message = direction == 'up' and 'Elevador subindo.' or 'Elevador descendo.'
    return setLiftHeightInternal(source, shopId, liftIndex, targetHeight, message)
end)

lib.callback.register('vrs_mechanic:server:saveLiftHeight', function(source, shopId, liftIndex)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local state = buildLiftState(shopId, liftIndex)
    if state.busy then
        return { success = false, reason = 'lift_busy' }
    end

    local presetKey = getPresetKey(source, shopId, liftIndex)
    if not presetKey then
        return { success = false, reason = 'no_access' }
    end

    savedLiftHeights[presetKey] = clampHeight(state.height) or (Config.Lift.MinHeight or 0.0)
    persistSavedHeights()

    return {
        success = true,
        state = enrichStateForSource(source, state, shopId, liftIndex),
        savedHeight = savedLiftHeights[presetKey],
        message = 'Altura atual salva com sucesso.',
    }
end)

lib.callback.register('vrs_mechanic:server:goToSavedLiftHeight', function(source, shopId, liftIndex)
    local presetKey = getPresetKey(source, shopId, liftIndex)
    if not presetKey or savedLiftHeights[presetKey] == nil then
        return { success = false, reason = 'no_saved_height' }
    end

    return setLiftHeightInternal(source, shopId, liftIndex, savedLiftHeights[presetKey], 'Elevador indo para a altura salva.')
end)

lib.callback.register('vrs_mechanic:server:resetLiftHeight', function(source, shopId, liftIndex)
    return setLiftHeightInternal(source, shopId, liftIndex, Config.Lift.MinHeight or 0.0, 'Elevador retornando para a posição inicial.')
end)

lib.callback.register('vrs_mechanic:server:resetSavedLiftHeight', function(source, shopId, liftIndex)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local state = buildLiftState(shopId, liftIndex)
    if state.busy then
        return { success = false, reason = 'lift_busy' }
    end

    local presetKey = getPresetKey(source, shopId, liftIndex)
    if not presetKey or savedLiftHeights[presetKey] == nil then
        return { success = false, reason = 'no_saved_height' }
    end

    savedLiftHeights[presetKey] = nil
    persistSavedHeights()

    return {
        success = true,
        state = enrichStateForSource(source, state, shopId, liftIndex),
        savedHeight = nil,
        message = 'Altura salva resetada com sucesso.',
    }
end)

lib.callback.register('vrs_mechanic:server:removeVehicleFromLift', function(source, shopId, liftIndex)
    local src = source
    local ok, reason = validateLiftAccess(src, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if state.busy then
        return { success = false, reason = 'lift_busy' }
    end

    if not state.vehicleNetId then
        return { success = false, reason = 'lift_empty' }
    end

    if (state.height or 0.0) > ((Config.Lift.MinHeight or 0.0) + (Config.Lift.positionTolerance or 0.02)) then
        return { success = false, reason = 'lift_not_lowered' }
    end

    VRS.LiftStates[key] = {
        shopId = shopId,
        liftIndex = liftIndex,
        height = Config.Lift.MinHeight or 0.0,
        targetHeight = Config.Lift.MinHeight or 0.0,
        minHeight = Config.Lift.MinHeight or 0.0,
        maxHeight = Config.Lift.MaxHeight or 1.2,
        level = 1,
        vehicleNetId = nil,
        plate = nil,
        busy = false,
    }

    syncLiftState(shopId, liftIndex)
    return { success = true }
end)

CreateThread(loadSavedHeights)
