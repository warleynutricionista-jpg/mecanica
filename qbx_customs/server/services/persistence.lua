local persistence = {}

local function getPlayerCitizenId(source)
    return exports.qbx_core:GetPlayer(source)?.PlayerData?.citizenid
end

local function sanitizePlate(plate)
    if type(plate) ~= 'string' then
        return nil
    end

    local sanitized = plate:match('^%s*(.-)%s*$')
    if not sanitized or sanitized == '' then
        return nil
    end

    return sanitized:sub(1, 15)
end

local function isVehicleOwnedByPlayer(source, plate)
    local citizenId = getPlayerCitizenId(source)
    if not citizenId then
        return false
    end

    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1', {
        plate,
        citizenId,
    }) and true or false
end

function persistence.saveVehicleProps(source, vehicleProps)
    if type(vehicleProps) ~= 'table' then
        return false
    end

    local plate = sanitizePlate(vehicleProps.plate)
    if not plate or not isVehicleOwnedByPlayer(source, plate) then
        return false
    end

    vehicleProps.plate = plate

    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ? LIMIT 1', {
        json.encode(vehicleProps),
        plate,
    })

    return true
end

return persistence
