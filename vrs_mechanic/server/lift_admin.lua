-- ============================================================
-- VRS_MECHANIC - LIFT ADMIN / PERSISTÊNCIA DE LAYOUT
-- ============================================================

local layoutFile = Config.Lift.LayoutFile or 'lift_layouts.json'
local savedLayouts = { version = 1, lastId = 0, lifts = {} }
local baseLiftLayouts = {}

local function deepCopy(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = deepCopy(entry)
    end
    return copy
end

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function ensureLayoutStore()
    savedLayouts.version = savedLayouts.version or 1
    savedLayouts.lastId = tonumber(savedLayouts.lastId) or 0
    savedLayouts.lifts = type(savedLayouts.lifts) == 'table' and savedLayouts.lifts or {}
end

local function getNextLiftId()
    savedLayouts.lastId = (tonumber(savedLayouts.lastId) or 0) + 1
    return ('lift_%04d'):format(savedLayouts.lastId)
end

local function getSerializedCoords(coords, heading)
    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        w = tonumber(heading or coords.w) or 0.0,
    }
end

local function getLiftRecordForSync(lift)
    return {
        id = lift.id,
        model = lift.model,
        ownerJob = lift.ownerJob,
        shopId = lift.shopId,
        category = lift.category,
        source = lift.source,
        staticIndex = lift.staticIndex,
        length = lift.length,
        width = lift.width,
        controlPanel = lift.controlPanel and getSerializedCoords(lift.controlPanel) or nil,
        coords = getSerializedCoords(lift.coords),
        metadata = deepCopy(lift.metadata or {}),
    }
end

local function getLiftById(shopId, liftId)
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts then return nil, nil end

    for liftIndex, lift in ipairs(shop.lifts) do
        if lift.id == liftId then
            return lift, liftIndex
        end
    end

    return nil, nil
end

local function shopHasBusyLift(shopId)
    if not VRS.LiftStates then return false end

    for liftIndex in ipairs(Config.Shops[shopId] and Config.Shops[shopId].lifts or {}) do
        local state = VRS.LiftStates[getLiftKey(shopId, liftIndex)]
        if state and (state.vehicleNetId or state.moving) then
            return true
        end
    end

    return false
end

local function clearShopLiftStates(shopId)
    if not VRS.LiftStates then return end

    for key in pairs(VRS.LiftStates) do
        if key:find(('^%s_'):format(shopId:gsub('([^%w])', '%%%1'))) then
            VRS.LiftStates[key] = nil
        end
    end
end

local function persistLiftLayouts()
    ensureLayoutStore()
    SaveResourceFile(GetCurrentResourceName(), layoutFile, json.encode(savedLayouts), -1)
end

local function loadLiftLayouts()
    local raw = LoadResourceFile(GetCurrentResourceName(), layoutFile)
    if not raw or raw == '' then
        savedLayouts = { version = 1, lastId = 0, lifts = {} }
        return
    end

    local decoded = json.decode(raw)
    if type(decoded) ~= 'table' then
        savedLayouts = { version = 1, lastId = 0, lifts = {} }
        return
    end

    savedLayouts = decoded
    ensureLayoutStore()
end

local function snapshotBaseLayouts()
    for shopId, shop in pairs(Config.Shops) do
        baseLiftLayouts[shopId] = deepCopy(shop.lifts or {})
    end
end

local function normalizeSavedRecord(record)
    if type(record) ~= 'table' then return nil end
    if not record.shopId or not record.id then return nil end

    record.coords = getSerializedCoords(record.coords or {})
    record.length = tonumber(record.length) or 5.0
    record.width = tonumber(record.width) or 2.5
    record.model = record.model or Config.Lift.DefaultModelName or 'standard_lift'
    record.category = record.category or record.shopId
    record.metadata = type(record.metadata) == 'table' and record.metadata or {}
    record.ownerJob = record.ownerJob or (Config.Shops[record.shopId] and Config.Shops[record.shopId].job) or nil
    if record.controlPanel then
        record.controlPanel = getSerializedCoords(record.controlPanel)
    end

    return record
end

local function rebuildLiftLayouts()
    ensureLayoutStore()

    for shopId, shop in pairs(Config.Shops) do
        local rebuilt = {}
        local staticLifts = baseLiftLayouts[shopId] or {}

        for staticIndex, baseLift in ipairs(staticLifts) do
            local merged = deepCopy(baseLift)
            merged.id = ('%s_static_%d'):format(shopId, staticIndex)
            merged.shopId = shopId
            merged.staticIndex = staticIndex
            merged.source = 'static'
            merged.model = merged.model or Config.Lift.DefaultModelName or 'standard_lift'
            merged.ownerJob = merged.ownerJob or shop.job
            merged.category = merged.category or shopId
            merged.metadata = type(merged.metadata) == 'table' and merged.metadata or {}

            local override = savedLayouts.lifts[merged.id]
            if override then
                override = normalizeSavedRecord(deepCopy(override))
                if override and not override.removed then
                    merged.coords = getSerializedCoords(override.coords, override.heading)
                    merged.length = override.length or merged.length
                    merged.width = override.width or merged.width
                    merged.controlPanel = override.controlPanel or merged.controlPanel
                    merged.model = override.model or merged.model
                    merged.ownerJob = override.ownerJob or merged.ownerJob
                    merged.category = override.category or merged.category
                    merged.metadata = deepCopy(override.metadata or merged.metadata)
                else
                    merged = nil
                end
            end

            if merged then
                rebuilt[#rebuilt + 1] = merged
            end
        end

        local customLifts = {}
        for _, record in pairs(savedLayouts.lifts) do
            if record.shopId == shopId and record.source == 'custom' and not record.removed then
                customLifts[#customLifts + 1] = normalizeSavedRecord(deepCopy(record))
            end
        end

        table.sort(customLifts, function(a, b)
            return (a.sortOrder or 0) < (b.sortOrder or 0)
        end)

        for _, record in ipairs(customLifts) do
            rebuilt[#rebuilt + 1] = {
                id = record.id,
                model = record.model,
                ownerJob = record.ownerJob,
                shopId = record.shopId,
                category = record.category,
                source = 'custom',
                staticIndex = nil,
                length = record.length,
                width = record.width,
                controlPanel = record.controlPanel,
                coords = getSerializedCoords(record.coords),
                metadata = deepCopy(record.metadata or {}),
            }
        end

        shop.lifts = rebuilt
    end
end

function VRS.GetLiftLayoutsForSync()
    local payload = {}

    for shopId, shop in pairs(Config.Shops) do
        payload[shopId] = {}
        for _, lift in ipairs(shop.lifts or {}) do
            payload[shopId][#payload[shopId] + 1] = getLiftRecordForSync(lift)
        end
    end

    return payload
end

function VRS.CanManageLifts(source, shopId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then
        return false, 'no_player'
    end

    local ace = Config.Lift.AdminAce
    if ace and ace ~= '' and IsPlayerAceAllowed(source, ace) then
        return true, 'admin'
    end

    if not shopId then
        for id, shop in pairs(Config.Shops) do
            if shop.type == 'owned' and VRS.IsManager(source, id) then
                if not Config.Lift.AdminRequireDuty or VRS.IsOnDuty(source) then
                    return true, 'manager'
                end
            end
        end

        return false, Config.Lift.AdminRequireDuty and 'not_on_duty' or 'no_permission'
    end

    local shop = Config.Shops[shopId]
    if not shop then
        return false, 'invalid_shop'
    end

    if shop.type ~= 'owned' then
        return false, 'no_permission'
    end

    if not VRS.HasShopAccess(source, shopId) then
        return false, 'no_access'
    end

    if Config.Lift.AdminRequireDuty and not VRS.IsOnDuty(source) then
        return false, 'not_on_duty'
    end

    if not VRS.IsManager(source, shopId) and not (VRS.IsBoss and VRS.IsBoss(source, shopId)) then
        return false, 'no_permission'
    end

    return true, 'manager'
end

function VRS.GetManageableLiftShops(source)
    local shops = {}

    for shopId, shop in pairs(Config.Shops) do
        local allowed = VRS.CanManageLifts(source, shopId)
        if allowed then
            shops[#shops + 1] = {
                shopId = shopId,
                label = shop.label,
                job = shop.job,
                type = shop.type,
                liftCount = #(shop.lifts or {}),
            }
        end
    end

    table.sort(shops, function(a, b)
        return a.label < b.label
    end)

    return shops
end

local function syncLayouts(target)
    TriggerClientEvent('vrs_mechanic:client:syncLiftLayouts', target or -1, VRS.GetLiftLayoutsForSync())
end

local function validateMutation(source, shopId, liftId)
    local allowed, reason = VRS.CanManageLifts(source, shopId)
    if not allowed then
        return false, reason
    end

    if shopHasBusyLift(shopId) then
        return false, 'shop_busy'
    end

    if liftId then
        local lift = getLiftById(shopId, liftId)
        if not lift then
            return false, 'invalid_lift'
        end
    end

    return true, nil
end

lib.callback.register('vrs_mechanic:server:getLiftLayouts', function(source)
    return {
        allowed = VRS.CanManageLifts(source),
        shops = VRS.GetManageableLiftShops(source),
        layouts = VRS.GetLiftLayoutsForSync(),
    }
end)

lib.callback.register('vrs_mechanic:server:saveLiftLayout', function(source, payload)
    if type(payload) ~= 'table' then
        return { success = false, reason = 'invalid_payload' }
    end

    local shopId = payload.shopId
    local coords = payload.coords
    if not shopId or type(coords) ~= 'table' then
        return { success = false, reason = 'invalid_payload' }
    end

    local isEdit = payload.liftId ~= nil
    local ok, reason = validateMutation(source, shopId, payload.liftId)
    if not ok then
        return { success = false, reason = reason }
    end

    local shop = Config.Shops[shopId]
    local heading = tonumber(payload.heading or coords.w) or 0.0
    local serializedCoords = getSerializedCoords(coords, heading)

    if isEdit then
        local existing = getLiftById(shopId, payload.liftId)
        if not existing then
            return { success = false, reason = 'invalid_lift' }
        end

        local recordId = existing.id
        local record = savedLayouts.lifts[recordId] or {
            id = recordId,
            shopId = shopId,
            source = existing.source == 'custom' and 'custom' or 'static',
            staticIndex = existing.staticIndex,
            sortOrder = existing.metadata and existing.metadata.sortOrder,
        }

        record.shopId = shopId
        record.coords = serializedCoords
        record.heading = heading
        record.length = tonumber(payload.length or existing.length) or existing.length or 5.0
        record.width = tonumber(payload.width or existing.width) or existing.width or 2.5
        record.controlPanel = payload.controlPanel and getSerializedCoords(payload.controlPanel) or (existing.controlPanel and getSerializedCoords(existing.controlPanel)) or nil
        record.model = payload.model or existing.model or Config.Lift.DefaultModelName or 'standard_lift'
        record.ownerJob = payload.ownerJob or existing.ownerJob or shop.job
        record.category = payload.category or existing.category or shopId
        record.metadata = deepCopy(payload.metadata or existing.metadata or {})
        record.removed = false
        savedLayouts.lifts[recordId] = record
    else
        local id = getNextLiftId()
        savedLayouts.lifts[id] = {
            id = id,
            shopId = shopId,
            source = 'custom',
            coords = serializedCoords,
            heading = heading,
            length = tonumber(payload.length) or 5.0,
            width = tonumber(payload.width) or 2.5,
            controlPanel = payload.controlPanel and getSerializedCoords(payload.controlPanel) or nil,
            model = payload.model or Config.Lift.DefaultModelName or 'standard_lift',
            ownerJob = payload.ownerJob or shop.job,
            category = payload.category or shopId,
            metadata = deepCopy(payload.metadata or {}),
            removed = false,
            sortOrder = os.time() + savedLayouts.lastId,
        }
    end

    persistLiftLayouts()
    rebuildLiftLayouts()
    clearShopLiftStates(shopId)
    syncLayouts()

    return {
        success = true,
        layouts = VRS.GetLiftLayoutsForSync(),
    }
end)

lib.callback.register('vrs_mechanic:server:deleteLiftLayout', function(source, shopId, liftId)
    if not shopId or not liftId then
        return { success = false, reason = 'invalid_payload' }
    end

    local ok, reason = validateMutation(source, shopId, liftId)
    if not ok then
        return { success = false, reason = reason }
    end

    local existing = getLiftById(shopId, liftId)
    if not existing then
        return { success = false, reason = 'invalid_lift' }
    end

    if existing.source == 'custom' then
        savedLayouts.lifts[liftId] = nil
    else
        local record = savedLayouts.lifts[liftId] or {
            id = liftId,
            shopId = shopId,
            source = 'static',
            staticIndex = existing.staticIndex,
        }
        record.removed = true
        savedLayouts.lifts[liftId] = record
    end

    persistLiftLayouts()
    rebuildLiftLayouts()
    clearShopLiftStates(shopId)
    syncLayouts()

    return {
        success = true,
        layouts = VRS.GetLiftLayoutsForSync(),
    }
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(source)
    syncLayouts(source)
end)

RegisterNetEvent('vrs_mechanic:server:requestLiftLayouts', function()
    syncLayouts(source)
end)

CreateThread(function()
    snapshotBaseLayouts()
    loadLiftLayouts()
    rebuildLiftLayouts()
end)

VRS.LiftAdminAvailable = true
