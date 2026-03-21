local sharedConfig = require 'config.shared'

local access = {}

local function playerHasAnyJob(source, jobs)
    if not jobs or #jobs == 0 then
        return false
    end

    local playerJob = exports.qbx_core:GetPlayer(source)?.PlayerData?.job?.name
    if not playerJob then
        return false
    end

    for i = 1, #jobs do
        if playerJob == jobs[i] then
            return true
        end
    end

    return false
end

function access.getZoneConfig(zoneId)
    return zoneId and sharedConfig.zones[zoneId] or nil
end

function access.isFreeModAllowed(source, zoneId)
    local zone = access.getZoneConfig(zoneId)
    return zone and playerHasAnyJob(source, zone.freeMods) or false
end

function access.isFreeRepairAllowed(source, zoneId)
    local zone = access.getZoneConfig(zoneId)
    return zone and playerHasAnyJob(source, zone.freeRepair) or false
end

return access
