local function invalid(reason)
    return { ok = false, reason = reason }
end

local function success(data)
    return { ok = true, data = data }
end

lib.callback.register('mm_carkeys:client:entityState', function(request)
    if type(request) ~= 'table' then
        return invalid('invalid_request')
    end

    local action = request.action
    local netId = request.netId
    if type(action) ~= 'string' or type(netId) ~= 'number' then
        return invalid('invalid_payload')
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return invalid('entity_not_in_scope')
    end

    local payload = request.payload or {}

    if action == 'npcStatus' then
        return success({
            isDead = IsEntityDead(entity),
            inVehicle = IsPedInAnyVehicle(entity, false)
        })
    end

    if action == 'doorAngles' then
        if not IsEntityAVehicle(entity) then
            return invalid('not_vehicle')
        end

        local doors = payload.doors
        if type(doors) ~= 'table' or #doors == 0 then
            return invalid('invalid_doors')
        end

        local result = {}
        for _, doorIndex in ipairs(doors) do
            if type(doorIndex) == 'number' then
                result[doorIndex] = GetVehicleDoorAngleRatio(entity, doorIndex)
            end
        end

        return success({ angles = result })
    end

    return invalid('unknown_action')
end)

