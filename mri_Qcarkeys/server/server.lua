local Bridge = require 'server.bridge'
local Guard = require 'server.modules.action_guard'

local VehicleList = {}
local VehicleData = {}
local SpawnedVehicles = {}
local TempKeyCleanupRunning = false
local getItemInfo = Shared.Inventory == 'qb' and function(item) return item.info end or function(item) return item.metadata end

local function debugLog(message, ...)
    Shared.DebugPrint(message, ...)
end

local function isValidVehicleEntity(entity)
    if type(entity) ~= 'number' or entity <= 0 then return false end
    if not DoesEntityExist(entity) then return false end

    local entityType = GetEntityType(entity)
    if entityType ~= 2 then
        debugLog('invalid vehicle entity reference=%s entityType=%s', entity, entityType or 'nil')
        return false
    end

    return true
end

local function isValidPlate(plate)
    return Shared.GetPlateKey(plate) ~= nil
end

local function normPlate(plate)
    return Shared.GetPlateKey(plate) or ''
end

local function getCitizenVehicleList(citizenid)
    if not citizenid then return nil end
    VehicleList[citizenid] = VehicleList[citizenid] or {
        plates = {},
        netIds = {},
        meta = {}
    }
    return VehicleList[citizenid]
end

local function ensureVehicleData(plate)
    plate = normPlate(plate)
    if plate == '' then return nil end
    if not VehicleData[plate] then
        VehicleData[plate] = {
            has_key = false,
            key_taken = false,
            key_location = nil,
            searched_glovebox = false,
            searched_trunk = false,
            assigned_key_holder = nil,
            ignition_damaged = false,
            electrical_failure_permanent = false,
            lockpick_in_progress = false,
            hotwire_in_progress = false,
            vehicle_net = nil,
            status = Shared.vehicleState.states.normal
        }
    end
    return VehicleData[plate]
end

local function pickKeyLocation()
    local glove = Config.SearchKey.GloveboxChance or 0
    local trunk = Config.SearchKey.TrunkChance or 0
    local npc = (Config.NPCSearch.Enabled and Config.NPCSearch.KeyChance) or 0
    local none = Config.SearchKey.NoKeyChance or 0
    local total = glove + trunk + npc + none
    if total <= 0 then return 'none' end

    local roll = math.random() * total
    if roll <= glove then return 'glovebox' end
    if roll <= glove + trunk then return 'trunk' end
    if roll <= glove + trunk + npc then return 'npc' end
    return 'none'
end

local function syncEntityState(vehicle, data)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    Guard:SetEntityStates(vehicle, {
        has_key = data.has_key,
        key_taken = data.key_taken,
        key_location = data.key_location,
        searched_glovebox = data.searched_glovebox,
        searched_trunk = data.searched_trunk,
        assigned_key_holder = data.assigned_key_holder,
        ignition_damaged = data.ignition_damaged,
        electrical_failure_permanent = data.electrical_failure_permanent,
        lockpick_in_progress = data.lockpick_in_progress,
        hotwire_in_progress = data.hotwire_in_progress,
        vehicle_status = data.status
    })
end

local function getVehicleFromNetId(netId)
    if type(netId) ~= 'number' or netId <= 0 then return 0 end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not isValidVehicleEntity(vehicle) then return 0 end
    return vehicle
end

local function getIdentityFromNetId(netId, ownerSource)
    local vehicle = getVehicleFromNetId(netId)
    if vehicle == 0 then return nil end
    return Shared.GetVehicleIdentity(vehicle, ownerSource)
end

local function resolveVehicleReference(vehicleOrNetId, ownerSource)
    if type(vehicleOrNetId) ~= 'number' or vehicleOrNetId <= 0 then return nil end

    if NetworkDoesNetworkIdExist(vehicleOrNetId) then
        local identity = getIdentityFromNetId(vehicleOrNetId, ownerSource)
        if identity then return identity end
    end

    if isValidVehicleEntity(vehicleOrNetId) then
        return Shared.GetVehicleIdentity(vehicleOrNetId, ownerSource)
    end

    return nil
end

local function resolveVehicleAndState(netId)
    local identity = getIdentityFromNetId(netId)
    if not identity or not identity.plateKey then return 0 end
    local data = ensureVehicleData(identity.plateKey)
    if not data.key_location then
        data.key_location = pickKeyLocation()
    end
    data.vehicle_net = identity.netId
    syncEntityState(identity.entity, data)
    return identity.entity, identity.plateKey, data
end

local function buildTempKeyPayload(plate, netId, metadata)
    metadata = metadata or {}
    return {
        plate = Shared.NormalizePlate(plate),
        plateKey = normPlate(plate),
        netId = type(netId) == 'number' and netId > 0 and netId or nil,
        expiresAt = metadata.expiresAt,
        category = metadata.category,
        reason = metadata.reason,
        temporary = metadata.temporary ~= false
    }
end

local function scheduleTempKeyCleanup()
    if TempKeyCleanupRunning then return end
    TempKeyCleanupRunning = true

    CreateThread(function()
        while TempKeyCleanupRunning do
            local now = os.time()
            local foundExpiringKey = false

            for citizenid, data in pairs(VehicleList) do
                for plate, meta in pairs(data.meta or {}) do
                    if meta.expiresAt then
                        foundExpiringKey = true
                        if meta.expiresAt <= now then
                            data.plates[plate] = nil
                            data.meta[plate] = nil
                            if meta.netId then
                                data.netIds[meta.netId] = nil
                            end
                        end
                    end
                end

                if not next(data.plates) and not next(data.netIds) then
                    VehicleList[citizenid] = nil
                end
            end

            if not foundExpiringKey then
                TempKeyCleanupRunning = false
                break
            end

            Wait(30000)
        end
    end)
end

local function setTempKeyForPlayer(id, plate, netId, metadata)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not citizenid then return false end

    local list = getCitizenVehicleList(citizenid)
    local payload = buildTempKeyPayload(plate, netId, metadata)
    local hasIdentifier = false

    if payload.plateKey ~= '' then
        list.plates[payload.plateKey] = true
        list.meta[payload.plateKey] = payload
        hasIdentifier = true
    end

    if payload.netId then
        list.netIds[payload.netId] = true
        hasIdentifier = true
    end

    if not hasIdentifier then return false end

    if Shared.tempKeys.autoExpire and not payload.expiresAt then
        payload.expiresAt = os.time() + math.floor((Shared.tempKeys.expire or 30) * 60)
        if payload.plateKey ~= '' then
            list.meta[payload.plateKey] = payload
        end
        scheduleTempKeyCleanup()
    end

    debugLog('temporary key granted src=%s plate=%s netId=%s category=%s reason=%s', id, payload.plateKey ~= '' and payload.plateKey or 'nil', payload.netId or 'nil', payload.category or 'default', payload.reason or 'none')
    TriggerClientEvent('mm_carkeys:client:addtempkeys', id, payload)
    return true
end

function GiveTempKeys(id, vehicleOrPlate, metadata)
    if not Shared.tempKeys.enabled then return false end

    metadata = metadata or {}
    local plate, netId = vehicleOrPlate, metadata.netId
    if type(vehicleOrPlate) == 'number' then
        local identity = resolveVehicleReference(vehicleOrPlate, id)
        if not identity then return false end
        plate = identity.plate
        netId = identity.netId
    end

    local granted = setTempKeyForPlayer(id, plate, netId, metadata)
    if granted then
        TriggerClientEvent('ox_lib:notify', id, {
            title = 'Recebido',
            description = 'Você recebeu a chave temporária para o veículo',
            type = 'success'
        })
    end

    return granted
end

local function removeTempKeyForPlayer(id, vehicleOrPlate, metadata)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not citizenid then return false end
    local list = VehicleList[citizenid]
    if not list then return false end

    metadata = metadata or {}
    local plate = type(vehicleOrPlate) == 'number' and nil or vehicleOrPlate
    local netId = metadata.netId
    if type(vehicleOrPlate) == 'number' then
        local identity = resolveVehicleReference(vehicleOrPlate, id)
        plate = identity and identity.plate or nil
        netId = identity and identity.netId or vehicleOrPlate
    end

    local plateKey = normPlate(plate)
    local removed = false

    if plateKey ~= '' then
        removed = list.plates[plateKey] ~= nil or removed
        list.plates[plateKey] = nil
        local meta = list.meta[plateKey]
        if meta and meta.netId then
            list.netIds[meta.netId] = nil
        end
        list.meta[plateKey] = nil
    end

    if type(netId) == 'number' and netId > 0 and list.netIds[netId] then
        removed = true
        list.netIds[netId] = nil
        for storedPlate, meta in pairs(list.meta) do
            if meta.netId == netId then
                list.meta[storedPlate] = nil
                list.plates[storedPlate] = nil
            end
        end
    end

    if removed then
        debugLog('temporary key removed src=%s plate=%s netId=%s', id, plateKey ~= '' and plateKey or 'nil', netId or 'nil')
        TriggerClientEvent('mm_carkeys:client:removetempkeys', id, buildTempKeyPayload(plate, netId, metadata))
    end

    return removed
end

function RemoveTempKeys(id, vehicleOrPlate, metadata)
    return removeTempKeyForPlayer(id, vehicleOrPlate, metadata)
end

local function givePermanentKeys(id, vehicleOrPlate, metadata)
    metadata = metadata or {}
    local plate = vehicleOrPlate
    if type(vehicleOrPlate) == 'number' then
        local identity = resolveVehicleReference(vehicleOrPlate, id)
        if not identity or not identity.plateKey then return false end
        plate = identity.plate
    end

    local plateKey = normPlate(plate)
    if plateKey == '' then return false end

    local Player = Bridge:GetPlayer(id)
    if not Player then return false end

    return Bridge:AddItem(id, 'vehiclekey', {
        label = ('CHAVE-%s'):format(plateKey),
        plate = plateKey
    })
end

local function removePermanentKeys(id, plate)
    local plateKey = normPlate(plate)
    if plateKey == '' then return false end
    local keys = Bridge:GetPlayerItemsByName(id, 'vehiclekey')
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info and normPlate(info.plate) == plateKey then
            Bridge:RemoveItem(id, 'vehiclekey', v.slot)
            return true
        end
    end
    return false
end

local function hasPermanentKeys(id, vehicleOrPlate)
    local plate = vehicleOrPlate
    if type(vehicleOrPlate) == 'number' then
        local identity = resolveVehicleReference(vehicleOrPlate, id)
        if not identity or not identity.plateKey then return false end
        plate = identity.plate
    end
    return lib.callback.await('mm_carkeys:client:havekey', id, 'perma', plate)
end

local function hasAnyKeys(id, vehicleOrPlate, metadata)
    metadata = metadata or {}
    local plate = type(vehicleOrPlate) == 'number' and nil or vehicleOrPlate
    local netId = metadata.netId
    if type(vehicleOrPlate) == 'number' then
        local identity = resolveVehicleReference(vehicleOrPlate, id)
        plate = identity and identity.plate or nil
        netId = identity and identity.netId or vehicleOrPlate
    end

    return lib.callback.await('mm_carkeys:client:havekey', id, 'temp', { plate = plate, netId = netId })
        or hasPermanentKeys(id, vehicleOrPlate)
end

local function registerSpawnedVehicle(ownerSource, vehicleOrNetId, options)
    options = options or {}
    if not ownerSource or ownerSource <= 0 then return false, 'invalid_source' end

    local identity = resolveVehicleReference(vehicleOrNetId, ownerSource)
    if not identity or not identity.netId then return false, 'invalid_vehicle' end

    local netId = identity.netId
    local vehicle = identity.entity

    local entityOwner = NetworkGetEntityOwner(vehicle)
    local ped = GetPlayerPed(ownerSource)
    local driver = ped ~= 0 and GetPedInVehicleSeat(vehicle, -1) or 0
    if entityOwner ~= -1 and entityOwner ~= ownerSource and driver ~= ped then
        debugLog('spawn registration denied src=%s netId=%s owner=%s driverMatch=%s', ownerSource, netId, entityOwner, driver == ped)
        return false, 'ownership_mismatch'
    end

    SpawnedVehicles[netId] = {
        source = ownerSource,
        category = options.category or 'generic',
        temporary = options.temporary ~= false,
        createdAt = os.time(),
        plate = identity.plate,
        plateKey = identity.plateKey,
        model = identity.model,
        expiresAt = options.expiresAt,
        reason = options.reason,
        cleanupOnDelete = options.cleanupOnDelete ~= false,
    }

    local vehicleData = identity.plateKey and ensureVehicleData(identity.plateKey) or nil
    if vehicleData then
        vehicleData.vehicle_net = identity.netId
        vehicleData.has_key = true
        syncEntityState(vehicle, vehicleData)
    end

    local shouldTemp = options.temporary ~= false
    if shouldTemp then
        local granted = GiveTempKeys(ownerSource, identity.plate or identity.netId, {
            netId = identity.netId,
            expiresAt = options.expiresAt,
            category = options.category,
            reason = options.reason or 'spawn_registration',
            temporary = true
        })
        if not granted and identity.netId then
            local fallbackGranted = GiveTempKeys(ownerSource, identity.netId, {
                netId = identity.netId,
                expiresAt = options.expiresAt,
                category = options.category,
                reason = options.reason or 'spawn_registration_pending_plate',
                temporary = true
            })
            if not fallbackGranted then
                return false, 'grant_failed'
            end
        end
    else
        if not givePermanentKeys(ownerSource, identity.plate) then
            return false, 'grant_failed'
        end
    end

    debugLog('spawn registered src=%s netId=%s plate=%s category=%s temporary=%s', ownerSource, identity.netId, identity.plateKey or 'nil', options.category or 'generic', shouldTemp)
    return true, identity
end

local function assignKeysOnServiceSpawn(ownerSource, vehicleOrNetId, options)
    if not Config.GiveTempKeysToServiceVehicles then return false, 'disabled' end
    options = options or {}
    options.category = 'service'
    options.temporary = options.temporary ~= false
    options.reason = options.reason or 'service_spawn'
    return registerSpawnedVehicle(ownerSource, vehicleOrNetId, options)
end

local function assignKeysOnAdminSpawn(ownerSource, vehicleOrNetId, options)
    if not Config.GiveKeysToAdminSpawnedVehicles then return false, 'disabled' end
    options = options or {}
    options.category = 'admin'
    options.temporary = options.temporary ~= false
    options.reason = options.reason or 'admin_spawn'
    return registerSpawnedVehicle(ownerSource, vehicleOrNetId, options)
end

local function grantVehicleKey(source, vehicle, plate, data)
    if data.key_taken then return false end
    data.key_taken = true
    data.has_key = true
    syncEntityState(vehicle, data)
    debugLog('key granted src=%s plate=%s', source, plate)
    GiveTempKeys(source, plate, { netId = NetworkGetNetworkIdFromEntity(vehicle), reason = 'script_action', category = 'interaction' })
    return true
end

lib.callback.register('mm_carkeys:server:getvehiclekeys', function(source)
    local citizenid = Bridge:GetPlayerCitizenId(source)
    return getCitizenVehicleList(citizenid) or { plates = {}, netIds = {}, meta = {} }
end)

lib.callback.register('mm_carkeys:server:getVehicleState', function(_, plate)
    if not isValidPlate(plate) then return false end
    return ensureVehicleData(plate)
end)

lib.callback.register('mm_carkeys:server:hasItem', function(source, item, amount)
    if type(item) ~= 'string' or item == '' then return false end
    return Bridge:HasItem(source, item, amount)
end)

lib.callback.register('mm_carkeys:server:consumeItem', function(source, item, amount)
    if type(item) ~= 'string' or item == '' then return false end
    return Bridge:TryRemoveItem(source, item, amount)
end)

lib.callback.register('mm_carkeys:server:beginCompartmentSearch', function(source, vehNetId, compartment)
    if not Config.SearchKey.Enabled then return false, 'disabled' end
    if compartment ~= 'glovebox' and compartment ~= 'trunk' then return false, 'invalid' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'search', plate) then return false, 'cooldown' end

    local searched = compartment == 'glovebox' and data.searched_glovebox or data.searched_trunk
    if searched then return false, 'already_searched' end
    if data.key_taken then return false, 'taken' end
    if not Guard:CanSearchCompartment(source, vehNetId, vehicle, compartment) then return false, 'closed' end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'search', source)
    if not ok then return false, 'busy' end

    local token = Guard:OpenAction(source, 'search', {
        plate = plate,
        vehicle = vehicle,
        compartment = compartment,
        duration = Config.SearchKey.Duration,
        lockKey = lockKey
    })

    return true, { token = token, duration = Config.SearchKey.Duration }
end)

lib.callback.register('mm_carkeys:server:completeCompartmentSearch', function(source, token, success)
    local action = Guard:GetAction(token, source, 'search')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle = data.vehicle
    local plate = data.plate
    local vehicleData = ensureVehicleData(plate)

    if not success then
        Guard:CloseAction(token)
        return false, 'cancelled'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:Debug('exploit: fast search src=%s plate=%s', source, plate)
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        Guard:CloseAction(token)
        return false, 'invalid_vehicle'
    end

    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if data.compartment == 'glovebox' then vehicleData.searched_glovebox = true else vehicleData.searched_trunk = true end

    local found = vehicleData.key_location == data.compartment and grantVehicleKey(source, vehicle, plate, vehicleData)
    syncEntityState(vehicle, vehicleData)
    Guard:CloseAction(token)

    return found, found and 'found' or 'empty'
end)

lib.callback.register('mm_carkeys:server:beginNpcSearch', function(source, vehNetId, pedNetId)
    if not Config.NPCSearch.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    local npc = NetworkGetEntityFromNetworkId(pedNetId)
    if npc == 0 or not DoesEntityExist(npc) or IsPedAPlayer(npc) then return false, 'invalid_npc' end

    if not Guard:ValidateDistance(source, npc, Config.NPCSearch.MaxDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'npc', plate) then return false, 'cooldown' end
    if data.key_taken then return false, 'taken' end

    if not data.assigned_key_holder then
        data.assigned_key_holder = pedNetId
    end

    if data.assigned_key_holder ~= pedNetId then
        return false, 'invalid_holder'
    end

    if data.key_location ~= 'npc' then
        return false, 'no_key'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'npc', source)
    if not ok then return false, 'busy' end

    local token = Guard:OpenAction(source, 'npc_search', {
        plate = plate,
        vehicle = vehicle,
        npc = npc,
        npcNet = pedNetId,
        duration = Config.NPCSearch.Duration,
        lockKey = lockKey
    })

    data.has_key = false
    syncEntityState(vehicle, data)

    return true, { token = token, duration = Config.NPCSearch.Duration }
end)

lib.callback.register('mm_carkeys:server:completeNpcSearch', function(source, token, success)
    local action = Guard:GetAction(token, source, 'npc_search')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle, npc = data.vehicle, data.npc
    local state = ensureVehicleData(data.plate)

    if not success then
        Guard:CloseAction(token)
        return false, 'cancelled'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) or npc == 0 or not DoesEntityExist(npc) then
        state.key_location = 'none'
        state.key_taken = true
        Guard:CloseAction(token)
        return false, 'escaped'
    end

    local npcStillNearby = Guard:ValidateDistance(source, npc, Config.NPCSearch.MaxDistance)
    local npcStateOk, npcState = Guard:AwaitClientEntityState(source, data.npcNet, 'npcStatus')

    if not npcStillNearby or not npcStateOk or type(npcState) ~= 'table' or npcState.isDead or npcState.inVehicle then
        state.key_location = 'none'
        state.key_taken = true
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return false, 'escaped'
    end

    local found = grantVehicleKey(source, vehicle, data.plate, state)
    Guard:CloseAction(token)
    return found, found and 'found' or 'no_key'
end)

lib.callback.register('mm_carkeys:server:beginHotwire', function(source, vehNetId)
    if not Config.Hotwire.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'hotwire', plate) then return false, 'cooldown' end

    if data.electrical_failure_permanent and Config.Hotwire.BlockIfPermanentDamage then
        return false, 'permanent_damage'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'hotwire', source)
    if not ok then return false, 'busy' end

    if Config.Hotwire.ConsumeItem then
        if not Bridge:HasItem(source, Config.Hotwire.RequiredItem, 1) then
            Guard:ReleaseVehicleLock(lockKey)
            return false, 'missing_item'
        end
        if not Bridge:TryRemoveItem(source, Config.Hotwire.RequiredItem, 1) then
            Guard:ReleaseVehicleLock(lockKey)
            return false, 'missing_item'
        end
        Guard:Debug('item consumed src=%s item=%s', source, Config.Hotwire.RequiredItem)
    end

    data.hotwire_in_progress = true
    syncEntityState(vehicle, data)

    local token = Guard:OpenAction(source, 'hotwire', {
        plate = plate,
        vehicle = vehicle,
        duration = Config.Hotwire.Duration,
        lockKey = lockKey
    })

    return true, { token = token, duration = Config.Hotwire.Duration }
end)

lib.callback.register('mm_carkeys:server:completeHotwire', function(source, token, minigameSuccess)
    local action = Guard:GetAction(token, source, 'hotwire')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle, plate = data.vehicle, data.plate
    local state = ensureVehicleData(plate)
    state.hotwire_in_progress = false

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        Guard:CloseAction(token)
        return false, 'invalid_vehicle'
    end

    if not minigameSuccess then
        state.ignition_damaged = true
        if math.random() <= Config.Hotwire.PermanentElectricalDamageChance then
            state.electrical_failure_permanent = true
        end
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return false, state.electrical_failure_permanent and 'permanent_damage' or 'failed'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if math.random() <= Config.Hotwire.SuccessChance then
        local granted = grantVehicleKey(source, vehicle, plate, state)
        state.hotwire_in_progress = false
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return granted, granted and 'success' or 'failed'
    end

    state.ignition_damaged = true
    if math.random() <= Config.Hotwire.PermanentElectricalDamageChance then
        state.electrical_failure_permanent = true
    end
    syncEntityState(vehicle, state)
    Guard:CloseAction(token)
    return false, state.electrical_failure_permanent and 'permanent_damage' or 'failed'
end)

lib.callback.register('mm_carkeys:server:beginLockpick', function(source, vehNetId, mode)
    if not Config.Lockpick.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'lockpick', plate) then return false, 'cooldown' end

    if data.electrical_failure_permanent and mode == 'engine' then
        return false, 'permanent_damage'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'lockpick', source)
    if not ok then return false, 'busy' end

    data.lockpick_in_progress = true
    syncEntityState(vehicle, data)

    local token = Guard:OpenAction(source, 'lockpick', {
        plate = plate,
        vehicle = vehicle,
        mode = mode,
        currentStage = 1,
        requiredStages = Config.Lockpick.Stages,
        lockKey = lockKey
    })

    return true, { token = token, stage = 1, requiredStages = Config.Lockpick.Stages }
end)

lib.callback.register('mm_carkeys:server:lockpickStage', function(source, token, stageSuccess)
    local action = Guard:GetAction(token, source, 'lockpick')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle = data.vehicle
    if vehicle == 0 or not DoesEntityExist(vehicle) or not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if stageSuccess then
        data.currentStage = data.currentStage + 1
        if data.currentStage > data.requiredStages then
            local state = ensureVehicleData(data.plate)
            state.lockpick_in_progress = false
            state.has_key = true
            syncEntityState(vehicle, state)
            if data.mode == 'door' then
                SetVehicleDoorsLocked(vehicle, 1)
            end
            GiveTempKeys(source, data.plate)
            Guard:CloseAction(token)
            return true, 'completed'
        end
        return true, { stage = data.currentStage, requiredStages = data.requiredStages }
    end

    if Config.Lockpick.FailMode == 'regress' then
        data.currentStage = math.max(1, data.currentStage - (Config.Lockpick.RegressAmount or 1))
        return false, { stage = data.currentStage, requiredStages = data.requiredStages, regress = true }
    end

    local state = ensureVehicleData(data.plate)
    state.lockpick_in_progress = false
    syncEntityState(vehicle, state)
    Guard:CloseAction(token)
    return false, 'failed'
end)

RegisterNetEvent('mm_carkeys:server:cancelAction', function(token)
    local src = source
    local action = Guard:GetAction(token, src)
    if not action then return end
    local data = action.data
    if data and data.plate then
        local state = ensureVehicleData(data.plate)
        state.lockpick_in_progress = false
        state.hotwire_in_progress = false
        if data.vehicle and DoesEntityExist(data.vehicle) then
            syncEntityState(data.vehicle, state)
        end
    end
    Guard:CloseAction(token)
end)

RegisterNetEvent('mm_carkeys:server:repairVehicleElectrical', function(vehNetId)
    local src = source
    local vehicle, _, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 or not Guard:ValidateDistance(src, vehicle, Shared.security.maxInteractDistance + 2.0) then return end
    data.ignition_damaged = false
    data.electrical_failure_permanent = false
    syncEntityState(vehicle, data)
end)

RegisterNetEvent('mm_carkeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    local vehicle = getVehicleFromNetId(vehNetId)
    if vehicle == 0 or not Guard:ValidateDistance(src, vehicle, Shared.security.maxInteractDistance + 5.0) then return end
    SetVehicleDoorsLocked(vehicle, state)
end)

RegisterNetEvent('mm_carkeys:server:acquiretempvehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    GiveTempKeys(src, plate, { reason = 'compat_temp', category = 'compat' })
end)

RegisterNetEvent('mm_carkeys:server:removetempvehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    RemoveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:giveTemporaryKeys', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    GiveTempKeys(src, payload.plate or payload.netId, payload)
end)

RegisterNetEvent('mm_carkeys:server:givePermanentKeys', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    givePermanentKeys(src, payload.plate or payload.netId, payload)
end)

RegisterNetEvent('mm_carkeys:server:removeKeys', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    RemoveTempKeys(src, payload.plate or payload.netId, payload)
    if payload.plate then
        removePermanentKeys(src, payload.plate)
    end
end)

RegisterNetEvent('mm_carkeys:server:registerSpawnedVehicle', function(netId, options)
    local src = source
    if type(netId) ~= 'number' then return end
    registerSpawnedVehicle(src, netId, options or {})
end)

RegisterNetEvent('mm_carkeys:server:claimFallbackSpawnKeys', function(netId, options)
    local src = source
    if not Config.AdminSpawnFallback or type(netId) ~= 'number' then return end
    options = options or {}
    options.category = options.category or 'admin'
    options.temporary = true
    options.reason = options.reason or 'fallback_spawn'
    registerSpawnedVehicle(src, netId, options)
end)

RegisterNetEvent('mm_carkeys:server:assignKeysOnServiceSpawn', function(netId, options)
    local src = source
    if type(netId) ~= 'number' then return end
    assignKeysOnServiceSpawn(src, netId, options or {})
end)

RegisterNetEvent('mm_carkeys:server:assignKeysOnAdminSpawn', function(netId, options)
    local src = source
    if type(netId) ~= 'number' then return end
    assignKeysOnAdminSpawn(src, netId, options or {})
end)

RegisterNetEvent('mm_carkeys:server:removelockpick', function(item)
    local src = source
    if type(item) ~= 'string' or item == '' then
        debugLog('ignored lockpick removal with invalid item src=%s item=%s', src, tostring(item))
        return
    end
    Bridge:RemoveItem(src, item)
end)

RegisterNetEvent('mm_carkeys:server:acquirevehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    givePermanentKeys(src, plate)
end)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    givePermanentKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removevehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    removePermanentKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:setVehicleStatus', function(plate, status)
    if not isValidPlate(plate) then return end
    local data = ensureVehicleData(plate)
    if not data then return end
    data.status = status or Shared.vehicleState.states.normal
end)

RegisterNetEvent('mm_carkeys:server:stackkeys', function()
    local src = source
    local bagFound = Bridge:GetPlayerItemByName(src, 'keybag')
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    local plates, platesList = {}, {}
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info and info.plate then
            local plateKey = normPlate(info.plate)
            plates[#plates + 1] = { plate = plateKey, label = info.label }
            platesList[#platesList + 1] = plateKey
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
        end
    end
    if bagFound then
        local info = getItemInfo(bagFound)
        for _, v in pairs(info.plates or {}) do
            local plateKey = normPlate(v.plate)
            plates[#plates + 1] = { plate = plateKey, label = v.label }
            platesList[#platesList + 1] = plateKey
        end
        Bridge:RemoveItem(src, 'keybag', bagFound.slot)
    end
    Bridge:AddItem(src, 'keybag', { plates = plates, platestxt = table.concat(platesList, ', ') })
end)

RegisterNetEvent('mm_carkeys:server:unstackkeys', function()
    local src = source
    local bag = Bridge:GetPlayerItemByName(src, 'keybag')
    if not bag then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'Você não tem uma bolsa de chave', type = 'error' })
    end
    Bridge:RemoveItem(src, 'keybag', bag.slot)
    local itemInfo = getItemInfo(bag)
    for _, v in pairs(itemInfo.plates or {}) do
        Bridge:AddItem(src, 'vehiclekey', { label = v.label, plate = normPlate(v.plate) })
    end
end)

exports('GiveTempKeys', GiveTempKeys)
exports('GiveTemporaryKeys', function(src, vehicleOrPlate, metadata)
    return GiveTempKeys(src, vehicleOrPlate, metadata)
end)
exports('GivePermanentKeys', function(src, vehicleOrPlate, metadata)
    return givePermanentKeys(src, vehicleOrPlate, metadata)
end)
exports('RemoveTempKeys', RemoveTempKeys)
exports('RemoveKeys', function(src, vehicleOrPlate, metadata)
    local removedTemp = RemoveTempKeys(src, vehicleOrPlate, metadata)
    local removedPermanent = false
    if type(vehicleOrPlate) == 'string' then
        removedPermanent = removePermanentKeys(src, vehicleOrPlate)
    end
    return removedTemp or removedPermanent
end)
exports('HasKeys', function(src, vehicleOrPlate, metadata)
    return hasAnyKeys(src, vehicleOrPlate, metadata)
end)
exports('RegisterSpawnedVehicle', function(src, vehicleOrNetId, options)
    return registerSpawnedVehicle(src, vehicleOrNetId, options)
end)
exports('AssignKeysOnServiceSpawn', function(src, vehicleOrNetId, options)
    return assignKeysOnServiceSpawn(src, vehicleOrNetId, options)
end)
exports('AssignKeysOnAdminSpawn', function(src, vehicleOrNetId, options)
    return assignKeysOnAdminSpawn(src, vehicleOrNetId, options)
end)

exports('GiveKeyItem', function(src, plate)
    if not plate then return end
    TriggerClientEvent('mm_carkeys:client:setplayerkey', src, plate)
end)

exports('RemoveKeyItem', function(src, plate)
    if not plate then return end
    TriggerClientEvent('mm_carkeys:client:removeplayerkey', src, plate)
end)

exports('HaveTemporaryKey', function(src, plate, netId)
    if not plate and not netId then return false end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'temp', { plate = plate, netId = netId })
end)

exports('HavePermanentKey', function(src, plate)
    if not plate then return false end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'perma', plate)
end)

AddEventHandler('entityRemoved', function(entity)
    if not isValidVehicleEntity(entity) then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId <= 0 then return end

    local record = SpawnedVehicles[netId]
    if not record then return end

    if record.cleanupOnDelete and record.source then
        RemoveTempKeys(record.source, record.plate, { netId = netId })
    end

    SpawnedVehicles[netId] = nil
    if record.plateKey and VehicleData[record.plateKey] then
        VehicleData[record.plateKey].lockpick_in_progress = false
        VehicleData[record.plateKey].hotwire_in_progress = false
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = Bridge:GetPlayerCitizenId(src)
    if citizenid and VehicleList[citizenid] then
        VehicleList[citizenid] = nil
    end

    for netId, data in pairs(SpawnedVehicles) do
        if data.source == src then
            SpawnedVehicles[netId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, data in pairs(VehicleData) do
        data.lockpick_in_progress = false
        data.hotwire_in_progress = false
    end
end)
