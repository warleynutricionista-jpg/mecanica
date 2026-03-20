local VehicleSecurity = {}

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

function VehicleSecurity:GetVehicleState(plate)
    if not plate then return false end
    return lib.callback.await('mm_carkeys:server:getVehicleState', false, plate)
end

function VehicleSecurity:IsIgnitionJammed(vehicle, plate)
    local state = plate and self:GetVehicleState(plate)
    if state and state.electrical_failure_permanent and Config.Hotwire.BlockIfPermanentDamage then
        return true
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return GetVehicleEngineHealth(vehicle) <= Shared.ignition.jammedThreshold
end

function VehicleSecurity:NotifyIgnitionJammed(reason)
    local description = reason == 'mechanic_required' and Shared.text.mechanicRequired or 'A ignição encravou e precisa de reparo mecânico.'
    lib.notify({ title = 'Ignição encravada', description = description, type = 'error' })
end

function VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, damageAmount)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, 0.0 end
    local newHealth = math.max(0.0, GetVehicleEngineHealth(vehicle) - damageAmount)
    SetVehicleEngineHealth(vehicle, newHealth)
    if newHealth <= Shared.ignition.jammedThreshold then
        self:NotifyIgnitionJammed()
        return true, newHealth
    end
    return false, newHealth
end

function VehicleSecurity:TriggerTheftAlert(vehicle, description, alarmTime)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local vehClass = GetVehicleClass(vehicle)
    if Shared.alert and Shared.alert.silentClasses[vehClass] then
        local dispatchEvent = Shared.alert.dispatchEvent
        if dispatchEvent and dispatchEvent ~= '' then
            TriggerServerEvent(dispatchEvent, {
                code = '10-60',
                title = 'Alarme silencioso',
                description = description or ('Tentativa de furto em %s'):format(GetVehicleNumberPlateText(vehicle)),
                coords = GetEntityCoords(vehicle)
            })
        end
        return
    end
    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, alarmTime or 60000)
end

function VehicleSecurity:GetReputationLevel(skillName)
    if not Shared.reputation or not Shared.reputation.enabled then return 1 end
    if not resourceStarted(Shared.reputation.resource) then return 1 end
    local ok, level = pcall(function() return exports[Shared.reputation.resource]:getCurrentLevel(skillName) end)
    if not ok or type(level) ~= 'number' then return 1 end
    level = math.floor(level)
    if level < 1 then level = 1 end
    if level > Shared.reputation.maxLevel then level = Shared.reputation.maxLevel end
    return level
end

function VehicleSecurity:UpdateReputation(skillName, amount)
    if not Shared.reputation or not Shared.reputation.enabled then return end
    if not resourceStarted(Shared.reputation.resource) then return end
    pcall(function() exports[Shared.reputation.resource]:updateSkill(skillName, amount or 1) end)
end

function VehicleSecurity:RunHotwireMinigame()
    if Shared.hotwire.minigame == 'rep-enginewire' and resourceStarted('rep-enginewire') then
        local ok, result = pcall(function() return exports['rep-enginewire']:MiniGame() end)
        if ok then return result == true end
    end
    return lib.skillCheck(Shared.hotwire.skillDifficulty or { 'easy', 'easy' })
end

function VehicleSecurity:SetVehicleStatus(plate, status)
    if not plate or not status then return end
    TriggerServerEvent('mm_carkeys:server:setVehicleStatus', plate, status)
end

function VehicleSecurity:CanAttemptHotwire(plate)
    if not plate then return false, 'invalid' end
    return lib.callback.await('mm_carkeys:server:canAttemptHotwire', false, plate)
end

return VehicleSecurity
