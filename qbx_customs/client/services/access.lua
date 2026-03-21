local sharedConfig = require 'config.shared'

local access = {}

local function matchesJobWhitelist(zone)
    if not zone.job or not QBX?.PlayerData then
        return true
    end

    local playerJob = QBX.PlayerData.job.name
    for i = 1, #zone.job do
        if playerJob == zone.job[i] then
            return QBX.PlayerData.job.onduty
        end
    end

    return false
end

function access.isVehicleAllowed(zoneId, vehicle)
    local zone = sharedConfig.zones[zoneId]
    if not zone or not vehicle then
        return false
    end

    local vehicleClass = GetVehicleClass(vehicle)
    local model = GetEntityModel(vehicle)
    if zone.deniedClasses and zone.deniedClasses[vehicleClass] then
        return false
    end

    if zone.allowedClasses and not zone.allowedClasses[vehicleClass] then
        return false
    end

    if zone.modelBlacklist and zone.modelBlacklist[model] then
        return false
    end

    return matchesJobWhitelist(zone)
end

return access
