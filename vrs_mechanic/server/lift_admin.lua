-- ============================================================
-- VRS_MECHANIC - LIFT ADMIN / PERSISTÊNCIA DE LAYOUT
-- ============================================================

local layoutFile = Config.Lift.LayoutFile or 'lift_layouts.json'
local savedLayouts = { version = 1, lastId = 0, lifts = {} }
local baseLiftLayouts = {}
local discoveredWorldLifts = {}

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

local function getLiftManagementConfig()
    local configured = Config.Lift.Management or {}
    local commandList = type(Config.Lift.AdminCommands) == 'table' and Config.Lift.AdminCommands or nil

    return {
        requireDuty = configured.requireDuty ~= nil and configured.requireDuty or Config.Lift.AdminRequireDuty,
        allowAdminAce = configured.allowAdminAce ~= false,
        ace = configured.ace or Config.Lift.AdminAce,
        allowShopManagers = configured.allowShopManagers ~= false,
        allowBoss = configured.allowBoss ~= false,
        allowAuthorizedMechanics = configured.allowAuthorizedMechanics ~= false,
        defaultMinGrade = tonumber(configured.defaultMinGrade) or 0,
        jobs = type(configured.jobs) == 'table' and configured.jobs or {},
        debug = configured.debug == true or Config.Lift.Debug == true,
        commands = commandList or { Config.Lift.AdminCommand or 'liftadmin', 'elevadorcarro' },
    }
end

local function liftAdminLog(category, message)
    local management = getLiftManagementConfig()
    if not management.debug then return end

    print(('[vrs_mechanic][lift_admin][%s] %s'):format(category or 'general', message or ''))
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

local function normalizeLiftName(value)
    if type(value) ~= 'string' then return nil end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed == '' then
        return nil
    end

    return trimmed
end

local function getDefaultLiftName(shopId, numericId)
    local suffix = tonumber(numericId) or numericId or 1
    return ('Elevador %s'):format(tostring(suffix))
end

local function getLiftRecordForSync(lift)
    return {
        id = lift.id,
        liftName = lift.liftName,
        model = lift.model,
        ownerJob = lift.ownerJob,
        shopId = lift.shopId,
        category = lift.category,
        source = lift.source,
        staticIndex = lift.staticIndex,
        length = lift.length,
        width = lift.width,
        minHeight = lift.minHeight,
        maxHeight = lift.maxHeight,
        sourceType = lift.sourceType,
        useExistingEntity = lift.useExistingEntity,
        platformOffset = lift.platformOffset and getSerializedCoords(lift.platformOffset) or nil,
        vehicleOffset = lift.vehicleOffset and getSerializedCoords(lift.vehicleOffset) or nil,
        interactionOffset = lift.interactionOffset and getSerializedCoords(lift.interactionOffset) or nil,
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

local function getPlayerJobData(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    return player.PlayerData and player.PlayerData.job or nil
end

local function normalizeGradeLevel(job)
    if not job or not job.grade then return 0 end
    return tonumber(job.grade.level or job.grade) or 0
end

local function hasConfiguredJobPermission(source, shopId)
    local management = getLiftManagementConfig()
    local job = getPlayerJobData(source)
    local shop = Config.Shops[shopId]

    if not job or not shop then
        return false, 'no_player'
    end

    local jobRule = management.jobs[job.name]
    if jobRule == false then
        return false, 'no_permission'
    end

    if shop.job and job.name ~= shop.job and not (jobRule and jobRule.allowOtherShops == true) then
        return false, 'no_access'
    end

    if management.requireDuty and job.onduty ~= true then
        return false, 'not_on_duty'
    end

    local minGrade = management.defaultMinGrade
    local bossOnly = false
    local allowedGrades = nil

    if type(jobRule) == 'table' then
        if jobRule.enabled == false then
            return false, 'no_permission'
        end

        if tonumber(jobRule.minGrade) then
            minGrade = tonumber(jobRule.minGrade)
        end

        bossOnly = jobRule.bossOnly == true
        allowedGrades = type(jobRule.allowedGrades) == 'table' and jobRule.allowedGrades or nil
    elseif jobRule == true then
        minGrade = 0
    elseif jobRule == nil then
        minGrade = management.defaultMinGrade
    end

    if bossOnly and not (VRS.IsBoss and VRS.IsBoss(source, shopId)) then
        return false, 'no_permission'
    end

    local gradeLevel = normalizeGradeLevel(job)
    if allowedGrades and next(allowedGrades) then
        local matched = false
        for _, grade in ipairs(allowedGrades) do
            if gradeLevel == tonumber(grade) then
                matched = true
                break
            end
        end

        if not matched then
            return false, 'no_permission'
        end
    elseif gradeLevel < minGrade then
        return false, 'no_permission'
    end

    return true, 'mechanic'
end

local function validateSerializedCoords(coords)
    if type(coords) ~= 'table' then
        return false
    end

    return tonumber(coords.x) ~= nil
        and tonumber(coords.y) ~= nil
        and tonumber(coords.z) ~= nil
end

local function isDuplicateLiftName(shopId, liftName, ignoredLiftId)
    local normalizedName = normalizeLiftName(liftName)
    if not normalizedName then
        return false
    end

    for _, lift in ipairs(Config.Shops[shopId] and Config.Shops[shopId].lifts or {}) do
        if lift.id ~= ignoredLiftId then
            local existingName = normalizeLiftName(lift.liftName)
            if existingName and existingName:lower() == normalizedName:lower() then
                return true
            end
        end
    end

    return false
end

local function validateLiftPlacementData(shopId, liftId, coords)
    local shop = Config.Shops[shopId]
    if not shop or not shop.zones or not shop.zones.main then
        return false, 'invalid_shop'
    end

    if not validateSerializedCoords(coords) then
        return false, 'invalid_payload'
    end

    local zoneCenter = shop.zones.main.coords
    local distanceLimit = tonumber(Config.Lift.ValidationDistanceFromShop) or 35.0
    local placement = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    if #(placement - zoneCenter) > distanceLimit then
        return false, 'outside_shop'
    end

    local minSpacing = tonumber(Config.Lift.MinSpacing) or 4.0
    for _, lift in ipairs(shop.lifts or {}) do
        if lift.id ~= liftId then
            local dist = #(placement - vec3(lift.coords.x, lift.coords.y, lift.coords.z))
            if dist < minSpacing then
                return false, 'lift_overlap'
            end
        end
    end

    return true, nil
end

local function getWorldLiftId(shopId, model, coords)
    local hash = VRS.ResolveModelHash(model) or 0
    return ('%s_world_%s_%d_%d_%d'):format(
        shopId,
        tostring(hash),
        math.floor((coords.x or 0.0) * 100.0 + 0.5),
        math.floor((coords.y or 0.0) * 100.0 + 0.5),
        math.floor((coords.z or 0.0) * 100.0 + 0.5)
    )
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
    record.liftName = normalizeLiftName(record.liftName) or getDefaultLiftName(record.shopId, record.id and record.id:match('(%d+)$'))
    record.minHeight = tonumber(record.minHeight)
    record.maxHeight = tonumber(record.maxHeight)
    if record.controlPanel then
        record.controlPanel = getSerializedCoords(record.controlPanel)
    end

    return record
end

local function isNearLift(existingLifts, coords, tolerance)
    local placement = vec3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    for _, lift in ipairs(existingLifts) do
        local other = vec3(lift.coords.x, lift.coords.y, lift.coords.z)
        if #(placement - other) <= (tolerance or (Config.Lift.WorldDetection and Config.Lift.WorldDetection.dedupeDistance) or 1.5) then
            return true, lift
        end
    end

    return false, nil
end

local function rebuildLiftLayouts()
    ensureLayoutStore()

    for shopId, shop in pairs(Config.Shops) do
        local rebuilt = {}
        local staticLifts = baseLiftLayouts[shopId] or {}

        for staticIndex, baseLift in ipairs(staticLifts) do
            local merged = deepCopy(baseLift)
            merged.id = ('%s_static_%d'):format(shopId, staticIndex)
            merged.liftName = normalizeLiftName(merged.liftName) or getDefaultLiftName(shopId, staticIndex)
            merged.shopId = shopId
            merged.staticIndex = staticIndex
            merged.source = 'static'
            local profile = VRS.GetLiftModelProfile(merged.model or Config.Lift.DefaultModelName or 'standard_lift')
            merged.model = merged.model or Config.Lift.DefaultModelName or 'standard_lift'
            merged.ownerJob = merged.ownerJob or shop.job
            merged.category = merged.category or shopId
            merged.metadata = type(merged.metadata) == 'table' and merged.metadata or {}
            merged.minHeight = tonumber(merged.minHeight or profile.minHeight)
            merged.maxHeight = tonumber(merged.maxHeight or profile.maxHeight)
            merged.sourceType = merged.sourceType or profile.sourceType or 'spawned'
            merged.useExistingEntity = merged.useExistingEntity ~= nil and merged.useExistingEntity or profile.useExistingEntity or false
            merged.platformOffset = deepCopy(merged.platformOffset or profile.platformOffset)
            merged.vehicleOffset = deepCopy(merged.vehicleOffset or profile.vehicleOffset)
            merged.interactionOffset = deepCopy(merged.interactionOffset or profile.interactionOffset)

            local override = savedLayouts.lifts[merged.id]
            if override then
                override = normalizeSavedRecord(deepCopy(override))
                if override and not override.removed then
                    merged.coords = getSerializedCoords(override.coords, override.heading)
                    merged.length = override.length or merged.length
                    merged.width = override.width or merged.width
                    merged.controlPanel = override.controlPanel or merged.controlPanel
                    merged.liftName = normalizeLiftName(override.liftName) or merged.liftName
                    merged.model = override.model or merged.model
                    merged.ownerJob = override.ownerJob or merged.ownerJob
                    merged.category = override.category or merged.category
                    merged.metadata = deepCopy(override.metadata or merged.metadata)
                    merged.minHeight = override.minHeight or merged.minHeight
                    merged.maxHeight = override.maxHeight or merged.maxHeight
                    merged.sourceType = override.sourceType or merged.sourceType
                    merged.useExistingEntity = override.useExistingEntity ~= nil and override.useExistingEntity or merged.useExistingEntity
                    merged.platformOffset = deepCopy(override.platformOffset or merged.platformOffset)
                    merged.vehicleOffset = deepCopy(override.vehicleOffset or merged.vehicleOffset)
                    merged.interactionOffset = deepCopy(override.interactionOffset or merged.interactionOffset)
                else
                    merged = nil
                end
            end

            if merged then
                rebuilt[#rebuilt + 1] = merged
            end
        end

        local worldLifts = discoveredWorldLifts[shopId] or {}
        table.sort(worldLifts, function(a, b)
            return a.id < b.id
        end)

        for _, worldLift in ipairs(worldLifts) do
            local merged = normalizeSavedRecord(deepCopy(worldLift))
            local override = savedLayouts.lifts[merged.id]
            if override then
                override = normalizeSavedRecord(deepCopy(override))
                if override and not override.removed then
                    merged.coords = getSerializedCoords(override.coords, override.heading)
                    merged.length = override.length or merged.length
                    merged.width = override.width or merged.width
                    merged.controlPanel = override.controlPanel or merged.controlPanel
                    merged.liftName = normalizeLiftName(override.liftName) or merged.liftName
                    merged.model = override.model or merged.model
                    merged.ownerJob = override.ownerJob or merged.ownerJob
                    merged.category = override.category or merged.category
                    merged.metadata = deepCopy(override.metadata or merged.metadata)
                    merged.minHeight = override.minHeight or merged.minHeight
                    merged.maxHeight = override.maxHeight or merged.maxHeight
                    merged.sourceType = override.sourceType or merged.sourceType
                    merged.useExistingEntity = override.useExistingEntity ~= nil and override.useExistingEntity or merged.useExistingEntity
                    merged.platformOffset = deepCopy(override.platformOffset or merged.platformOffset)
                    merged.vehicleOffset = deepCopy(override.vehicleOffset or merged.vehicleOffset)
                    merged.interactionOffset = deepCopy(override.interactionOffset or merged.interactionOffset)
                else
                    merged = nil
                end
            end

            local duplicateWorldLift = merged and isNearLift(rebuilt, merged.coords) or false
            if merged and not duplicateWorldLift then
                rebuilt[#rebuilt + 1] = {
                    id = merged.id,
                    liftName = merged.liftName,
                    model = merged.model,
                    ownerJob = merged.ownerJob,
                    shopId = merged.shopId,
                    category = merged.category,
                    source = 'world',
                    staticIndex = nil,
                    length = merged.length,
                    width = merged.width,
                    controlPanel = merged.controlPanel,
                    coords = getSerializedCoords(merged.coords),
                    metadata = deepCopy(merged.metadata or {}),
                    minHeight = merged.minHeight,
                    maxHeight = merged.maxHeight,
                    sourceType = merged.sourceType or 'world',
                    useExistingEntity = merged.useExistingEntity ~= false,
                    interactionOffset = merged.interactionOffset,
                    platformOffset = merged.platformOffset,
                    vehicleOffset = merged.vehicleOffset,
                }
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
                liftName = record.liftName,
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
                minHeight = record.minHeight,
                maxHeight = record.maxHeight,
                sourceType = record.sourceType or 'spawned',
                useExistingEntity = record.useExistingEntity or false,
                interactionOffset = record.interactionOffset,
                platformOffset = record.platformOffset,
                vehicleOffset = record.vehicleOffset,
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

    local management = getLiftManagementConfig()
    local ace = management.ace
    if management.allowAdminAce and ace and ace ~= '' and IsPlayerAceAllowed(source, ace) then
        liftAdminLog('permissions', ('Acesso liberado via ACE para source=%s shop=%s'):format(source, tostring(shopId)))
        return true, 'admin'
    end

    if not shopId then
        for id, shop in pairs(Config.Shops) do
            if shop.type == 'owned' then
                local allowed, origin = VRS.CanManageLifts(source, id)
                if allowed then
                    return true, origin
                end
            end
        end

        liftAdminLog('permissions', ('Acesso global negado para source=%s'):format(source))
        return false, management.requireDuty and 'not_on_duty' or 'no_permission'
    end

    local shop = Config.Shops[shopId]
    if not shop then
        return false, 'invalid_shop'
    end

    if shop.type ~= 'owned' then
        return false, 'no_permission'
    end

    local mechanicReason = nil
    if management.allowAuthorizedMechanics then
        local mechanicAllowed, mechanicOrigin = hasConfiguredJobPermission(source, shopId)
        if mechanicAllowed then
            liftAdminLog('permissions', ('Acesso liberado via mecânico autorizado para source=%s shop=%s'):format(source, shopId))
            return true, mechanicOrigin
        end
        mechanicReason = mechanicOrigin
    end

    if management.allowShopManagers and VRS.HasShopAccess(source, shopId) then
        if management.requireDuty and not VRS.IsOnDuty(source) then
            return false, 'not_on_duty'
        end

        if VRS.IsManager(source, shopId) or (management.allowBoss and VRS.IsBoss and VRS.IsBoss(source, shopId)) then
            liftAdminLog('permissions', ('Acesso liberado via gerente/boss para source=%s shop=%s'):format(source, shopId))
            return true, 'manager'
        end
    end

    liftAdminLog('permissions', ('Acesso negado para source=%s shop=%s'):format(source, shopId))
    return false, mechanicReason or 'no_permission'
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
        liftAdminLog('mutation', ('Mutação negada para source=%s shop=%s lift=%s reason=%s'):format(source, tostring(shopId), tostring(liftId), tostring(reason)))
        return false, reason
    end

    if not VRS.CheckCooldown(source, 'liftAdmin') then
        return false, 'cooldown'
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
    local allowed, reason = VRS.CanManageLifts(source)
    liftAdminLog('fetch', ('Layout solicitado por source=%s allowed=%s reason=%s'):format(source, tostring(allowed), tostring(reason)))
    return {
        allowed = allowed,
        allowedReason = reason,
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

    local placementOk, placementReason = validateLiftPlacementData(shopId, payload.liftId, coords)
    if not placementOk then
        liftAdminLog('save', ('Validação de posição falhou para source=%s shop=%s lift=%s reason=%s'):format(source, shopId, tostring(payload.liftId), tostring(placementReason)))
        return { success = false, reason = placementReason }
    end

    local shop = Config.Shops[shopId]
    local heading = tonumber(payload.heading or coords.w) or 0.0
    local serializedCoords = getSerializedCoords(coords, heading)
    local liftName = normalizeLiftName(payload.liftName)
    if not liftName then
        return { success = false, reason = 'invalid_lift_name' }
    end
    if isDuplicateLiftName(shopId, liftName, payload.liftId) then
        return { success = false, reason = 'duplicate_lift_name' }
    end
    liftAdminLog('save', ('Persistindo elevador. source=%s shop=%s lift=%s edit=%s'):format(source, shopId, tostring(payload.liftId), tostring(isEdit)))

    if isEdit then
        local existing = getLiftById(shopId, payload.liftId)
        if not existing then
            return { success = false, reason = 'invalid_lift' }
        end

        local recordId = existing.id
        local record = savedLayouts.lifts[recordId] or {
            id = recordId,
            shopId = shopId,
            source = existing.source or 'static',
            staticIndex = existing.staticIndex,
            sortOrder = existing.metadata and existing.metadata.sortOrder,
        }

        record.shopId = shopId
        record.liftName = liftName
        record.coords = serializedCoords
        record.heading = heading
        record.length = tonumber(payload.length or existing.length) or existing.length or 5.0
        record.width = tonumber(payload.width or existing.width) or existing.width or 2.5
        record.controlPanel = payload.controlPanel and getSerializedCoords(payload.controlPanel) or (existing.controlPanel and getSerializedCoords(existing.controlPanel)) or nil
        record.model = payload.model or existing.model or Config.Lift.DefaultModelName or 'standard_lift'
        record.ownerJob = payload.ownerJob or existing.ownerJob or shop.job
        record.category = payload.category or existing.category or shopId
        record.metadata = deepCopy(payload.metadata or existing.metadata or {})
        record.minHeight = tonumber(payload.minHeight or existing.minHeight)
        record.maxHeight = tonumber(payload.maxHeight or existing.maxHeight)
        record.sourceType = payload.sourceType or existing.sourceType
        record.useExistingEntity = payload.useExistingEntity ~= nil and payload.useExistingEntity or existing.useExistingEntity
        record.platformOffset = deepCopy(payload.platformOffset or existing.platformOffset)
        record.vehicleOffset = deepCopy(payload.vehicleOffset or existing.vehicleOffset)
        record.interactionOffset = deepCopy(payload.interactionOffset or existing.interactionOffset)
        record.removed = false
        savedLayouts.lifts[recordId] = record
    else
        local id = getNextLiftId()
        savedLayouts.lifts[id] = {
            id = id,
            shopId = shopId,
            liftName = liftName,
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
            minHeight = tonumber(payload.minHeight),
            maxHeight = tonumber(payload.maxHeight),
            sourceType = payload.sourceType or 'spawned',
            useExistingEntity = payload.useExistingEntity or false,
            platformOffset = deepCopy(payload.platformOffset),
            vehicleOffset = deepCopy(payload.vehicleOffset),
            interactionOffset = deepCopy(payload.interactionOffset),
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
            source = existing.source or 'static',
            staticIndex = existing.staticIndex,
        }
        record.removed = true
        savedLayouts.lifts[liftId] = record
    end

    persistLiftLayouts()
    rebuildLiftLayouts()
    clearShopLiftStates(shopId)
    syncLayouts()
    liftAdminLog('delete', ('Elevador removido. source=%s shop=%s lift=%s'):format(source, shopId, liftId))

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

RegisterNetEvent('vrs_mechanic:server:registerWorldLifts', function(shopId, lifts)
    if not Config.Lift.WorldDetection or not Config.Lift.WorldDetection.enabled then return end
    if type(shopId) ~= 'string' or type(lifts) ~= 'table' then return end
    if not Config.Shops[shopId] then return end

    discoveredWorldLifts[shopId] = {}

    for _, lift in ipairs(lifts) do
        if type(lift) == 'table' and lift.coords and lift.model then
            local profile = VRS.GetLiftModelProfile(lift.model)
            local id = lift.id or getWorldLiftId(shopId, lift.model, lift.coords)
            discoveredWorldLifts[shopId][#discoveredWorldLifts[shopId] + 1] = {
                id = id,
                shopId = shopId,
                liftName = normalizeLiftName(lift.liftName) or getDefaultLiftName(shopId, id:match('(%d+)$')),
                source = 'world',
                model = lift.model,
                coords = getSerializedCoords(lift.coords, lift.coords.w),
                length = tonumber(lift.length) or profile.length or 5.0,
                width = tonumber(lift.width) or profile.width or 2.5,
                ownerJob = Config.Shops[shopId].job,
                category = shopId,
                metadata = deepCopy(lift.metadata or {}),
                minHeight = tonumber(lift.minHeight or profile.minHeight),
                maxHeight = tonumber(lift.maxHeight or profile.maxHeight),
                sourceType = 'world',
                useExistingEntity = true,
                platformOffset = deepCopy(lift.platformOffset or profile.platformOffset),
                vehicleOffset = deepCopy(lift.vehicleOffset or profile.vehicleOffset),
                interactionOffset = deepCopy(lift.interactionOffset or profile.interactionOffset),
            }
        end
    end

    rebuildLiftLayouts()
    clearShopLiftStates(shopId)
    syncLayouts()
end)

CreateThread(function()
    snapshotBaseLayouts()
    loadLiftLayouts()
    rebuildLiftLayouts()
end)

VRS.LiftAdminAvailable = true
