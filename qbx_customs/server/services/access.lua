local sharedConfig = require 'config.shared'

local access = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getPlayerJob(source)
    local player = getPlayer(source)
    if not player or not player.PlayerData then
        return nil
    end

    return player.PlayerData.job
end

local function hasJob(source, jobList)
    if type(jobList) ~= 'table' or #jobList == 0 then
        return false
    end

    local job = getPlayerJob(source)
    if not job or not job.name then
        return false
    end

    for i = 1, #jobList do
        if job.name == jobList[i] then
            return true
        end
    end

    return false
end

function access.getZone(zoneIndex)
    return sharedConfig.zones[zoneIndex]
end

function access.canOpen(source, zoneIndex)
    local zone = access.getZone(zoneIndex)
    if not zone then
        return false, 'zoneInvalid'
    end

    if zone.restrictedJobs then
        if not hasJob(source, zone.restrictedJobs) then
            return false, 'accessDenied'
        end

        if zone.requireDuty ~= false then
            local job = getPlayerJob(source)
            if not job or job.onduty ~= true then
                return false, 'accessDenied'
            end
        end
    end

    return true, zone
end

function access.isFreeAction(source, zoneIndex, serviceType)
    local zone = access.getZone(zoneIndex)
    if not zone then
        return false
    end

    local matched = serviceType == 'repair' and hasJob(source, zone.freeRepairJobs) or hasJob(source, zone.freeModJobs)
    if not matched then
        return false
    end

    if zone.requireDuty == false then
        return true
    end

    local job = getPlayerJob(source)
    return job and job.onduty == true or false
end

return access
