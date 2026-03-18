-- ============================================================
-- VRS_MECHANIC - LIFTS SERVER
-- ============================================================

VRS.LiftStates = VRS.LiftStates or {}

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function buildLiftState(shopId, liftIndex)
    local key = getLiftKey(shopId, liftIndex)
    return VRS.LiftStates[key] or {
        shopId = shopId,
        liftIndex = liftIndex,
        level = 1,
        vehicleNetId = nil,
        plate = nil,
        busy = false,
    }
end

local function syncLiftState(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    VRS.LiftStates[getLiftKey(shopId, liftIndex)] = state
    TriggerClientEvent('vrs_mechanic:client:syncLiftState', -1, shopId, liftIndex, state)
    return state
end

lib.callback.register('vrs_mechanic:server:getLiftState', function(source, shopId, liftIndex)
    if not Config.Shops[shopId] then
        return nil
    end

    local shop = Config.Shops[shopId]
    if shop.type == 'owned' and not VRS.HasShopAccess(source, shopId) then
        return nil
    end

    return syncLiftState(shopId, liftIndex)
end)

lib.callback.register('vrs_mechanic:server:placeVehicleOnLift', function(source, shopId, liftIndex, netId, plate)
    local src = source
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts or not shop.lifts[liftIndex] then
        return { success = false, reason = 'invalid_lift' }
    end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(src, shopId) then
            return { success = false, reason = 'no_access' }
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty(src) then
            return { success = false, reason = 'not_on_duty' }
        end
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
    state.level = 1
    state.busy = false
    VRS.LiftStates[key] = state

    syncLiftState(shopId, liftIndex)
    return { success = true, state = state }
end)

lib.callback.register('vrs_mechanic:server:updateLiftLevel', function(source, shopId, liftIndex, direction)
    local src = source
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts or not shop.lifts[liftIndex] then
        return { success = false, reason = 'invalid_lift' }
    end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(src, shopId) then
            return { success = false, reason = 'no_access' }
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty(src) then
            return { success = false, reason = 'not_on_duty' }
        end
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if not state.vehicleNetId and Config.Lift.requireVehicleToRaise then
        return { success = false, reason = 'lift_empty' }
    end

    local maxLevel = #Config.Lift.levels
    if direction == 'up' then
        if state.level >= maxLevel then
            return { success = false, reason = 'already_top' }
        end
        state.level = state.level + 1
    elseif direction == 'down' then
        if state.level <= 1 then
            return { success = false, reason = 'already_bottom' }
        end
        state.level = state.level - 1
    else
        return { success = false, reason = 'invalid_direction' }
    end

    VRS.LiftStates[key] = state
    syncLiftState(shopId, liftIndex)
    return { success = true, state = state }
end)

lib.callback.register('vrs_mechanic:server:removeVehicleFromLift', function(source, shopId, liftIndex)
    local src = source
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts or not shop.lifts[liftIndex] then
        return { success = false, reason = 'invalid_lift' }
    end

    if shop.type == 'owned' then
        if not VRS.HasShopAccess(src, shopId) then
            return { success = false, reason = 'no_access' }
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty(src) then
            return { success = false, reason = 'not_on_duty' }
        end
    end

    local key = getLiftKey(shopId, liftIndex)
    local state = buildLiftState(shopId, liftIndex)
    if not state.vehicleNetId then
        return { success = false, reason = 'lift_empty' }
    end

    if state.level > 1 then
        return { success = false, reason = 'lift_not_lowered' }
    end

    VRS.LiftStates[key] = {
        shopId = shopId,
        liftIndex = liftIndex,
        level = 1,
        vehicleNetId = nil,
        plate = nil,
        busy = false,
    }

    syncLiftState(shopId, liftIndex)
    return { success = true }
end)
