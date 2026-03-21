local ResourceName = GetCurrentResourceName()

local Framework = {
    name = nil,
    object = nil,
}

local BusyBooths = {}

local function detectFramework()
    if GetResourceState('qbx_core') == 'started' then
        Framework.name = 'qbox'
        return
    end

    if GetResourceState('qb-core') == 'started' then
        Framework.name = 'qbcore'
        Framework.object = exports['qb-core']:GetCoreObject()
        return
    end

    Framework.name = 'standalone'
end

detectFramework()

local function debug(message, payload)
    if not Config.Debug then return end
    print(('[%s] %s'):format(ResourceName, message))
    if payload then
        print(json.encode(payload))
    end
end

local function getBooth(boothId)
    local booth = Config.Locations and Config.Locations[tonumber(boothId)]
    if not booth or not booth.control or not booth.vehicle then
        return nil
    end
    return booth
end

local function getPlayerJob(source)
    if Framework.name == 'qbox' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or nil
    end

    if Framework.name == 'qbcore' then
        local player = Framework.object.Functions.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or nil
    end

    return nil
end

local function hasJobAccess(source, booth)
    local jobs = booth.jobs
    if jobs == false then return true end
    if not jobs or #jobs == 0 then jobs = Config.AllowedJobsFallback end
    if not jobs or #jobs == 0 then return true end

    local jobName = getPlayerJob(source)
    if not jobName then return false end

    for _, allowedJob in ipairs(jobs) do
        if allowedJob == jobName then
            return true
        end
    end

    return false
end

local function notifyBusyState(boothId, state)
    TriggerClientEvent('mri_Qpaintjob:client:setBoothBusy', -1, boothId, state)
end

local function buildToken(source, boothId)
    return ('%s:%s:%s'):format(source, boothId, math.random(100000, 999999))
end

local function releaseBooth(boothId, reason)
    local boothState = BusyBooths[boothId]
    if not boothState then return end
    BusyBooths[boothId] = nil
    notifyBusyState(boothId, false)
    TriggerClientEvent('mri_Qpaintjob:client:stopEffects', -1, boothId)
    debug('Cabine liberada', { boothId = boothId, reason = reason, owner = boothState.source })
end

local function getBoothState(boothId)
    local state = BusyBooths[boothId]
    if not state then return nil end

    if (os.time() - state.updatedAt) > Config.SessionTimeout then
        releaseBooth(boothId, 'timeout')
        return nil
    end

    return state
end

local function touchBooth(boothId)
    local state = BusyBooths[boothId]
    if not state then return end
    state.updatedAt = os.time()
    BusyBooths[boothId] = state
end

lib.callback.register('mri_Qpaintjob:server:beginSession', function(source, boothId, vehicleNetId)
    boothId = tonumber(boothId)
    vehicleNetId = tonumber(vehicleNetId) or 0

    local booth = getBooth(boothId)
    if not booth then
        return false, { message = 'Cabine inválida.' }
    end

    if vehicleNetId <= 0 then
        return false, { message = 'NetID do veículo inválido.' }
    end

    if not hasJobAccess(source, booth) then
        return false, { message = 'Seu job não possui acesso a esta cabine.' }
    end

    local currentState = getBoothState(boothId)
    if currentState and currentState.source ~= source then
        return false, { message = 'A cabine já está ocupada por outro profissional.' }
    end

    local token = currentState and currentState.token or buildToken(source, boothId)
    BusyBooths[boothId] = {
        source = source,
        token = token,
        vehicleNetId = vehicleNetId,
        status = 'reserved',
        updatedAt = os.time(),
    }

    notifyBusyState(boothId, true)
    debug('Sessão iniciada', { boothId = boothId, source = source, vehicleNetId = vehicleNetId })

    return true, { token = token }
end)

lib.callback.register('mri_Qpaintjob:server:getBusyBooths', function()
    local snapshot = {}

    for boothId in pairs(Config.Locations or {}) do
        snapshot[boothId] = getBoothState(boothId) ~= nil
    end

    return snapshot
end)

lib.callback.register('mri_Qpaintjob:server:startPaint', function(source, boothId, token, vehicleNetId, selection)
    boothId = tonumber(boothId)
    vehicleNetId = tonumber(vehicleNetId) or 0

    local booth = getBooth(boothId)
    local state = getBoothState(boothId)

    if not booth or not state then
        return false, { message = 'A cabine não está mais disponível.' }
    end

    if not hasJobAccess(source, booth) then
        return false, { message = 'Seu job perdeu acesso a esta cabine.' }
    end

    if state.source ~= source or state.token ~= token then
        return false, { message = 'Sessão de pintura inválida.' }
    end

    if vehicleNetId <= 0 then
        return false, { message = 'NetID do veículo inválido.' }
    end

    state.status = 'painting'
    state.updatedAt = os.time()
    state.vehicleNetId = vehicleNetId
    state.selection = selection
    BusyBooths[boothId] = state

    TriggerClientEvent('mri_Qpaintjob:client:playEffects', -1, boothId, state.vehicleNetId, selection and selection.primary or nil)
    debug('Pintura iniciada', { boothId = boothId, source = source, vehicleNetId = state.vehicleNetId })

    return true, { ok = true }
end)

RegisterNetEvent('mri_Qpaintjob:server:touchSession', function(boothId, token)
    local source = source
    boothId = tonumber(boothId)

    local state = getBoothState(boothId)
    if not state then return end
    if state.source ~= source or state.token ~= token then return end

    touchBooth(boothId)
end)

RegisterNetEvent('mri_Qpaintjob:server:finishPaint', function(boothId, token, completed)
    local source = source
    boothId = tonumber(boothId)
    local state = getBoothState(boothId)
    if not state then return end
    if state.source ~= source or state.token ~= token then return end

    TriggerClientEvent('mri_Qpaintjob:client:stopEffects', -1, boothId)
    releaseBooth(boothId, completed and 'completed' or 'cancelled')
end)

RegisterNetEvent('mri_Qpaintjob:server:releaseSession', function(boothId, token, reason)
    local source = source
    boothId = tonumber(boothId)
    local state = getBoothState(boothId)
    if not state then return end
    if state.source ~= source or state.token ~= token then return end

    releaseBooth(boothId, reason or 'released')
end)

AddEventHandler('playerDropped', function()
    local source = source
    for boothId, state in pairs(BusyBooths) do
        if state.source == source then
            releaseBooth(boothId, 'player_dropped')
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= ResourceName then return end
    detectFramework()
    for boothId in pairs(Config.Locations or {}) do
        BusyBooths[boothId] = nil
        notifyBusyState(boothId, false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= ResourceName then return end
    for boothId in pairs(BusyBooths) do
        TriggerClientEvent('mri_Qpaintjob:client:stopEffects', -1, boothId)
        notifyBusyState(boothId, false)
    end
end)
