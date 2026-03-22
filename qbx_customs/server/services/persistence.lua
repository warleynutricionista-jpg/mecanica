local sharedConfig = require 'config.shared'

local persistence = {}

local function normalizePlate(value)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:upper():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if normalized == '' then
        return nil
    end

    return normalized:sub(1, 15)
end

local function getVehicleRecordById(vehicleId)
    if not vehicleId then
        return nil
    end

    return MySQL.single.await('SELECT id, citizenid, mods, plate FROM player_vehicles WHERE id = ? LIMIT 1', { vehicleId })
end

local function getVehicleIdFromQbxVehicles(plate)
    if GetResourceState('qbx_vehicles') ~= 'started' then
        return nil
    end

    local ok, vehicleId = pcall(function()
        return exports.qbx_vehicles:GetVehicleIdByPlate(plate)
    end)

    if not ok then
        return nil
    end

    return vehicleId
end

function persistence.normalizeProps(props)
    if type(props) ~= 'table' then
        return nil, 'invalidProps'
    end

    local normalized = table.clone(props)
    normalized.plate = normalizePlate(normalized.plate)
    if not normalized.plate then
        return nil, 'invalidPlate'
    end

    return normalized, nil
end

function persistence.normalizePlate(plate)
    return normalizePlate(plate)
end

function persistence.getVehicleRecordByPlate(plate)
    local normalizedPlate = normalizePlate(plate)
    if not normalizedPlate then
        return nil
    end

    local vehicleId = getVehicleIdFromQbxVehicles(normalizedPlate)
    if vehicleId then
        local record = getVehicleRecordById(vehicleId)
        if record then
            return record
        end
    end

    return MySQL.single.await('SELECT id, citizenid, mods, plate FROM player_vehicles WHERE plate = ? LIMIT 1', { normalizedPlate })
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

function persistence.resolveVehicleRecord(plate)
    local normalizedPlate = normalizePlate(plate)
    if not normalizedPlate then
        return nil, 'invalidPlate'
    end

    local record = persistence.getVehicleRecordByPlate(normalizedPlate)
    return record, nil, normalizedPlate
end

function persistence.validateSessionVehicle(plate)
    local record, reason = persistence.resolveVehicleRecord(plate)
    if record then
        return true, record
    end

    if reason then
        return false, reason
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

    local record = persistence.getVehicleRecordByPlate(normalized.plate)
    if record then
        local saved = saveWithQbxVehicles(vehicleNetId, normalized)
        if saved == true then
            return true
        end

        return saveDirect(record, normalized)
    end

    if sharedConfig.allowTemporaryVehicles then
        return true
    end

    return false, 'notPersisted'
end

return persistence
