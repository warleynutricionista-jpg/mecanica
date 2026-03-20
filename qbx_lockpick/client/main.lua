local lockpickCallback = nil

local function isVrsMechanicActive()
    return GetResourceState('vrs_mechanic') == 'started'
end


local function getIntegrationMessage(reason)
    local fallback = {
        service_active = 'Este veículo está em serviço mecânico e não pode ser arrombado agora.',
        vehicle_on_lift = 'Este veículo está no elevador e o lockpick foi bloqueado.',
    }

    local ok, message = pcall(function()
        return exports.vrs_mechanic:GetIntegrationReasonMessage('lockpick', reason)
    end)

    return ok and message or fallback[reason] or 'A integração mecânica bloqueou o lockpick.'
end

local function getRelevantVehicle()
    if cache.vehicle and cache.vehicle ~= 0 and DoesEntityExist(cache.vehicle) then
        return cache.vehicle
    end

    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
end

local function validateLockpickIntegration(success)
    if not success or not isVrsMechanicActive() then
        return success
    end

    local vehicle = getRelevantVehicle()
    if not vehicle then
        return success
    end

    local ok, allowed, reason = pcall(function()
        return exports.vrs_mechanic:CanLockpickVehicle(vehicle)
    end)

    if not ok or allowed ~= false then
        return success
    end

    exports.qbx_core:Notify(getIntegrationMessage(reason), 'error')
    return false
end

AddEventHandler('qb-lockpick:client:openLockpick', function(callback)
    lockpickCallback = callback
    openLockpick(true)
end)

RegisterNUICallback('callback', function(data, cb)
    openLockpick(false)
    if lockpickCallback then
        lockpickCallback(validateLockpickIntegration(data.success))
    end
    cb('ok')
end)

RegisterNUICallback('exit', function(_, cb)
    openLockpick(false)
    cb('ok')
end)

openLockpick = function(bool)
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        action = 'ui',
        toggle = bool,
    })
    SetCursorLocation(0.5, 0.2)
    lockpicking = bool
end
