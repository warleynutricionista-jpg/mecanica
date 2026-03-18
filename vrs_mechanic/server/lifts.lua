-- ============================================================
-- VRS_MECHANIC - LIFTS SERVER
-- ============================================================

VRS.LiftStates = VRS.LiftStates or {}

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function clampHeight(height)
    return VRS.Clamp(height or 0.0, Config.Lift.MinHeight or 0.0, Config.Lift.MaxHeight or 1.35)
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
        vehicleNetId = nil,
        plate = nil,
        busy = false,
    }

    state.height = clampHeight(state.height)
    state.level = getLegacyLevelFromHeight(state.height)
    return state
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

local function setLiftHeightInternal(source, shopId, liftIndex, targetHeight)
    local ok, reason = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if not state.vehicleNetId and Config.Lift.requireVehicleToRaise then
        return { success = false, reason = 'lift_empty' }
    end

    local clamped = clampHeight(tonumber(targetHeight))
    if clamped == nil then
        return { success = false, reason = 'invalid_height' }
    end

    if math.abs(clamped - (state.height or 0.0)) <= 0.001 then
        if clamped <= (Config.Lift.MinHeight or 0.0) + 0.001 then
            return { success = false, reason = 'already_bottom' }
        elseif clamped >= (Config.Lift.MaxHeight or 1.35) - 0.001 then
            return { success = false, reason = 'already_top' }
        end
    end

    state.height = clamped
    state.level = getLegacyLevelFromHeight(clamped)
    VRS.LiftStates[key] = state

    return { success = true, state = syncLiftState(shopId, liftIndex) }
end

lib.callback.register('vrs_mechanic:server:getLiftState', function(source, shopId, liftIndex)
    local ok = validateLiftAccess(source, shopId, liftIndex)
    if not ok then
        return nil
    end

    return syncLiftState(shopId, liftIndex)
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
    if state.vehicleNetId and state.vehicleNetId ~= netId then
        return { success = false, reason = 'lift_occupied' }
    end

    state.vehicleNetId = netId
    state.plate = plate
    state.height = Config.Lift.MinHeight or 0.0
    state.level = getLegacyLevelFromHeight(state.height)
    state.busy = false
    VRS.LiftStates[key] = state

    syncLiftState(shopId, liftIndex)
    return { success = true, state = state }
end)

lib.callback.register('vrs_mechanic:server:setLiftHeight', function(source, shopId, liftIndex, targetHeight)
    return setLiftHeightInternal(source, shopId, liftIndex, targetHeight)
end)

lib.callback.register('vrs_mechanic:server:updateLiftLevel', function(source, shopId, liftIndex, direction)
    local state = buildLiftState(shopId, liftIndex)
    local step = Config.Lift.StepHeight or 0.15
    local targetHeight = (state.height or 0.0) + (direction == 'up' and step or -step)
    return setLiftHeightInternal(source, shopId, liftIndex, targetHeight)
end)

lib.callback.register('vrs_mechanic:server:removeVehicleFromLift', function(source, shopId, liftIndex)
    local src = source
    local ok, reason = validateLiftAccess(src, shopId, liftIndex)
    if not ok then
        return { success = false, reason = reason }
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if not state.vehicleNetId then
        return { success = false, reason = 'lift_empty' }
    end

    if (state.height or 0.0) > ((Config.Lift.MinHeight or 0.0) + 0.01) then
        return { success = false, reason = 'lift_not_lowered' }
    end

    VRS.LiftStates[key] = {
        shopId = shopId,
        liftIndex = liftIndex,
        height = Config.Lift.MinHeight or 0.0,
        level = 1,
        vehicleNetId = nil,
        plate = nil,
        busy = false,
    }

    syncLiftState(shopId, liftIndex)
    return { success = true }
end)
