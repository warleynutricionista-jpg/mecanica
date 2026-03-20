local ActionGuard = {
    playerCooldowns = {},
    vehicleLocks = {},
    activeActions = {}
}

local function now()
    return GetGameTimer()
end

local function round(v)
    return tonumber(string.format('%.2f', v))
end

function ActionGuard:GetPlate(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return (GetVehicleNumberPlateText(vehicle) or ''):gsub('%W', '')
end

function ActionGuard:ValidateSource(source)
    if not source or source <= 0 then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    return ped
end

function ActionGuard:ValidateDistance(source, entity, maxDistance)
    local ped = self:ValidateSource(source)
    if not ped then return false end
    if entity == 0 or not DoesEntityExist(entity) then return false end
    local a, b = GetEntityCoords(ped), GetEntityCoords(entity)
    return #(a - b) <= (maxDistance or Shared.security.maxInteractDistance)
end

function ActionGuard:CooldownKey(source, action, plate)
    return ('%s:%s:%s'):format(source, action, plate or 'none')
end

function ActionGuard:CheckCooldown(source, action, plate)
    local key = self:CooldownKey(source, action, plate)
    local at = self.playerCooldowns[key] or 0
    if at > now() then
        return false
    end
    self.playerCooldowns[key] = now() + Shared.security.actionCooldownMs
    return true
end

function ActionGuard:TryVehicleLock(plate, action, source)
    local key = ('%s:%s'):format(plate, action)
    if self.vehicleLocks[key] then return false end
    self.vehicleLocks[key] = source
    return true, key
end

function ActionGuard:ReleaseVehicleLock(lockKey)
    if lockKey then
        self.vehicleLocks[lockKey] = nil
    end
end

function ActionGuard:OpenAction(source, actionType, data)
    local token = ('%s:%s:%s'):format(source, actionType, now() + math.random(111, 999))
    self.activeActions[token] = {
        source = source,
        type = actionType,
        startedAt = now(),
        data = data or {}
    }
    return token
end

function ActionGuard:GetAction(token, source, actionType)
    local act = self.activeActions[token]
    if not act then return false end
    if source and act.source ~= source then return false end
    if actionType and act.type ~= actionType then return false end
    return act
end

function ActionGuard:CloseAction(token)
    local act = self.activeActions[token]
    if not act then return end
    if act.data and act.data.lockKey then
        self:ReleaseVehicleLock(act.data.lockKey)
    end
    self.activeActions[token] = nil
end

function ActionGuard:Debug(msg, ...)
    if not Config.Debug then return end
    print(('[mm_carkeys] '..msg):format(...))
end

function ActionGuard:SetEntityStates(vehicle, state)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local entity = Entity(vehicle)
    for k, v in pairs(state) do
        entity.state:set(k, v, true)
    end
end

function ActionGuard:GetEntityState(vehicle, key)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return Entity(vehicle).state[key]
end

function ActionGuard:AwaitClientEntityState(source, netId, action, payload)
    if type(source) ~= 'number' or source <= 0 then
        return false, 'invalid_source'
    end

    if type(netId) ~= 'number' or netId <= 0 then
        return false, 'invalid_netid'
    end

    local request = {
        netId = netId,
        action = action,
        payload = payload or {}
    }

    local okCall, response = pcall(lib.callback.await, 'mm_carkeys:client:entityState', source, request)
    if not okCall then
        self:Debug('entityState callback error src=%s netId=%s action=%s err=%s', source, netId, action, response)
        return false, 'callback_error'
    end

    if type(response) ~= 'table' or not response.ok then
        local reason = type(response) == 'table' and response.reason or 'no_response'
        self:Debug('entityState failed src=%s netId=%s action=%s reason=%s', source, netId, action, reason)
        return false, reason
    end

    return true, response.data or {}
end

function ActionGuard:CanSearchCompartment(source, vehNetId, vehicle, compartment)
    if not Config.SearchKey.RequireOpenCompartments then return true end
    if not self:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        return false
    end

    local doors = compartment == 'trunk' and { 5 } or compartment == 'glovebox' and { 0, 1 } or nil
    if not doors then return false end

    local ok, data = self:AwaitClientEntityState(source, vehNetId, 'doorAngles', {
        doors = doors
    })

    if not ok or type(data) ~= 'table' or type(data.angles) ~= 'table' then
        return false
    end

    if compartment == 'trunk' then
        return (tonumber(data.angles[5]) or 0.0) > 0.05
    end

    return (tonumber(data.angles[0]) or 0.0) > 0.05 or (tonumber(data.angles[1]) or 0.0) > 0.05
end

function ActionGuard:GetRoundedDistance(source, entity)
    local ped = self:ValidateSource(source)
    if not ped or entity == 0 or not DoesEntityExist(entity) then return -1 end
    return round(#(GetEntityCoords(ped) - GetEntityCoords(entity)))
end

return ActionGuard
