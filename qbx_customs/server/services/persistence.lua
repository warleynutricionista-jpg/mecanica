local sharedConfig = require 'config.shared'

local persistence = {}

local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    value = value:match('^%s*(.-)%s*$')
    if not value or value == '' then
        return nil
    end

    return value:sub(1, 15)
end

function persistence.normalizeProps(props)
    if type(props) ~= 'table' then
        return nil, 'invalidProps'
    end

    local normalized = table.clone(props)
    normalized.plate = trim(normalized.plate)
    if not normalized.plate then
        return nil, 'invalidPlate'
    end

    return normalized, nil
end

function persistence.getVehicleRecordByPlate(plate)
    return MySQL.single.await('SELECT id, citizenid, mods FROM player_vehicles WHERE plate = ? LIMIT 1', { trim(plate) })
end

local function mergeExistingPersistence(existingMods, newProps)
    if type(existingMods) ~= 'table' then
        return newProps
    end

    if existingMods.vrsMechanic and newProps.vrsMechanic == nil then
        newProps.vrsMechanic = existingMods.vrsMechanic
    end

    return newProps
end

local function saveWithQbxVehicles(vehicleNetId, props)
    if GetResourceState('qbx_vehicles') ~= 'started' then
        return false, 'qbxVehiclesUnavailable'
    end

    local entity = NetworkGetEntityFromNetworkId(vehicleNetId or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 'entityUnavailable'
    end

    local ok, success, err = pcall(function()
        return exports.qbx_vehicles:SaveVehicle(entity, { props = props })
    end)

    if not ok then
        return false, 'saveFailed'
    end

    if success == false then
        return false, err and err.code or 'saveFailed'
    end

    return true
end

local function saveDirect(record, props)
    local existing = record.mods and json.decode(record.mods) or nil
    props = mergeExistingPersistence(existing, props)

    MySQL.update.await([[
        UPDATE player_vehicles
        SET mods = ?, plate = ?, fuel = ?, engine = ?, body = ?
        WHERE id = ?
    ]], {
        json.encode(props),
        props.plate,
        props.fuelLevel or 100.0,
        props.engineHealth or 1000.0,
        props.bodyHealth or 1000.0,
        record.id,
    })

    return true
end

function persistence.validateSessionVehicle(plate)
    local record = persistence.getVehicleRecordByPlate(plate)
    if record then
        return true, record
    end

    if sharedConfig.allowTemporaryVehicles then
        return true, nil
    end

    return false, 'notPersisted'
end

function persistence.save(vehicleNetId, props)
    local normalized, reason = persistence.normalizeProps(props)
    if not normalized then
        return false, reason
    end

    local ok, recordOrReason = persistence.validateSessionVehicle(normalized.plate)
    if not ok then
        return false, recordOrReason
    end

    if recordOrReason then
        local saved = saveWithQbxVehicles(vehicleNetId, normalized)
        if saved == true then
            return true
        end

        return saveDirect(recordOrReason, normalized)
    end

    return true
end

return persistence
