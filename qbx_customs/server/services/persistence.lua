local persistence = {}

local function isVehicleOwned(plate)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) and true or false
end

function persistence.saveVehicleProps(vehicleProps)
    if not vehicleProps or not vehicleProps.plate or not isVehicleOwned(vehicleProps.plate) then
        return false
    end

    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {
        json.encode(vehicleProps),
        vehicleProps.plate,
    })

    return true
end

return persistence
