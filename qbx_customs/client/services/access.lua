local sharedConfig = require 'config.shared'

local access = {}

local function getPlayerJob()
    if not QBX or not QBX.PlayerData then
        return nil
    end

    return QBX.PlayerData.job
end

local function hasJobMatch(jobList)
    if type(jobList) ~= 'table' or #jobList == 0 then
        return false
    end

    local playerJob = getPlayerJob()
    if not playerJob or not playerJob.name then
        return false
    end

    for i = 1, #jobList do
        if playerJob.name == jobList[i] then
            return true
        end
    end

    return false
end

local function passesJobRestriction(zone)
    if not zone.restrictedJobs then
        return true
    end

    if not hasJobMatch(zone.restrictedJobs) then
        return false
    end

    if zone.requireDuty == false then
        return true
    end

    local playerJob = getPlayerJob()
    return playerJob and playerJob.onduty == true or false
end

function access.getZoneByIndex(zoneIndex)
    return sharedConfig.zones[zoneIndex]
end

function access.isZoneAllowed(zoneIndex)
    local zone = access.getZoneByIndex(zoneIndex)
    if not zone then
        return false
    end

    return passesJobRestriction(zone)
end

function access.isVehicleAllowed(zoneIndex, vehicle)
    local zone = access.getZoneByIndex(zoneIndex)
    if not zone or not vehicle or vehicle == 0 then
        return false
    end

    if not passesJobRestriction(zone) then
        return false
    end

    local vehicleClass = GetVehicleClass(vehicle)
    if zone.deniedClasses and zone.deniedClasses[vehicleClass] then
        return false
    end

    if zone.allowedClasses and not zone.allowedClasses[vehicleClass] then
        return false
    end

    local model = GetEntityModel(vehicle)
    if zone.modelBlacklist and zone.modelBlacklist[model] then
        return false
    end

    return true
end

function access.isFreeService(zoneIndex, serviceType)
    local zone = access.getZoneByIndex(zoneIndex)
    if not zone then
        return false
    end

    local matched = serviceType == 'repair' and hasJobMatch(zone.freeRepairJobs) or hasJobMatch(zone.freeModJobs)
    if not matched then
        return false
    end

    if zone.requireDuty == false then
        return true
    end

    local playerJob = getPlayerJob()
    return playerJob and playerJob.onduty == true or false
end

return access
