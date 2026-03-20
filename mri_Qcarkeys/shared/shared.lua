local cfg = Config or {}

Shared = {
    debug = {
        enabled = cfg.Debug or false,
        ignition = cfg.Debug or false,
        hotwire = cfg.Debug or false,
        vehicleKeys = cfg.Debug or false,
    },
    text = cfg.Locale or {},
    ignition = {
        lockpickFailDamage = 45.0,
        hotwireFailDamage = 60.0,
        jammedThreshold = 200.0
    },
    alert = {
        silentClasses = { [6] = true, [7] = true },
        dispatchEvent = 'dispatch:server:notify'
    },
    reputation = {
        enabled = true,
        resource = 'cw-rep',
        maxLevel = 8
    },
    LockNPCVehicle = false,
    playerDraggable = true,
    toggleLightsOnlyRemote = true,
    keepVehicleEngineOn = true,
    keepKeysInVehicle = true,
    steal = {
        available = true,
        getKey = 'permanent',
        label = 'Assaltando...',
        minTime = 5000,
        maxTime = 7000,
        stressIncrease = math.random(1, 3),
        chance = {
            ['2685387236'] = 0.0, ['416676503'] = 0.5, ['-957766203'] = 0.75,
            ['860033945'] = 0.90, ['970310034'] = 0.90, ['1159398588'] = 0.99,
            ['3082541095'] = 0.99, ['2725924767'] = 0.99, ['1548507267'] = 0.0, ['4257178988'] = 0.0
        },
        armedNpcChance = 0.35,
        npcGunWeapons = { 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_MICROSMG' },
        npcAccuracy = 40,
        npcAggressiveness = 2,
    },
    blacklistedClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
    grab = {
        alive = true,
        leaveKeysOnVehicle = true,
        label = 'Roubando veículo...'
    },
    hotwire = {
        available = cfg.Hotwire and cfg.Hotwire.Enabled ~= false or true,
        stageOneLabel = 'Removendo proteção da ignição...',
        stageTwoLabel = 'Conectando fios da ignição...',
        chance = cfg.Hotwire and cfg.Hotwire.SuccessChance or 0.25,
        minTime = cfg.Hotwire and cfg.Hotwire.Duration or 9000,
        maxTime = cfg.Hotwire and cfg.Hotwire.Duration or 9000,
        stressIncrease = math.random(1, 3),
        minigame = 'ox_lib',
        skillDifficulty = { 'easy', 'medium', 'medium' },
        requiredItem = cfg.Hotwire and cfg.Hotwire.RequiredItem or 'screwdriver',
        consumeItem = cfg.Hotwire and cfg.Hotwire.ConsumeItem ~= false or true,
        severeDamageChance = cfg.Hotwire and cfg.Hotwire.SevereDamageChance or 0.70,
        irreversibleDamageChance = cfg.Hotwire and cfg.Hotwire.PermanentElectricalDamageChance or 0.45,
        blockIfPermanentDamage = cfg.Hotwire and cfg.Hotwire.BlockIfPermanentDamage ~= false or true,
        blockEngineOnPermanentDamage = cfg.Hotwire and cfg.Hotwire.BlockEngineOnPermanentDamage ~= false or true
    },
    lockpick = {
        minigameScript = 'ox_lib',
        stressIncrease = math.random(1, 3),
        breakChance = cfg.Lockpick and cfg.Lockpick.BreakChance or 0.5,
        advancedBreakChance = cfg.Lockpick and cfg.Lockpick.AdvancedBreakChance or 0.1,
        stages = cfg.Lockpick and cfg.Lockpick.Stages or 6,
        failMode = cfg.Lockpick and cfg.Lockpick.FailMode or 'fail',
        regressAmount = cfg.Lockpick and cfg.Lockpick.RegressAmount or 1,
        stageDuration = cfg.Lockpick and cfg.Lockpick.StageDuration or 1200
    },
    items = {
        lockpick = cfg.Lockpick and cfg.Lockpick.Item or 'lockpick',
        advancedLockpick = cfg.Lockpick and cfg.Lockpick.AdvancedItem or 'advancedlockpick',
    },
    security = {
        actionCooldownMs = cfg.Security and cfg.Security.ActionCooldownMs or 1200,
        maxInteractDistance = cfg.Security and cfg.Security.MaxInteractDistance or 5.0,
    },
    searchKey = cfg.SearchKey or {},
    npcSearch = cfg.NPCSearch or {},
    tempKeys = {
        enabled = cfg.TempKeysEnabled ~= false,
        expire = cfg.TempKeyExpireMinutes and cfg.TempKeyExpireMinutes > 0 and cfg.TempKeyExpireMinutes or 30,
        autoExpire = cfg.TempKeyAutoExpire ~= false,
        serviceEnabled = cfg.GiveTempKeysToServiceVehicles ~= false,
        adminEnabled = cfg.GiveKeysToAdminSpawnedVehicles ~= false,
        adminFallback = cfg.AdminSpawnFallback ~= false,
    },
    vehicleState = {
        states = {
            normal = 'normal',
            breached = 'breached'
        }
    },
    BlackListedWeapon = {
        'WEAPON_UNARMED', 'WEAPON_Knife', 'WEAPON_Nightstick', 'WEAPON_HAMMER', 'WEAPON_Bat',
        'WEAPON_Crowbar', 'WEAPON_Golfclub', 'WEAPON_Bottle', 'WEAPON_Dagger', 'WEAPON_Hatchet',
        'WEAPON_KnuckleDuster', 'WEAPON_Machete', 'WEAPON_Flashlight', 'WEAPON_SwitchBlade',
        'WEAPON_Poolcue', 'WEAPON_Wrench', 'WEAPON_Battleaxe', 'WEAPON_Grenade', 'WEAPON_StickyBomb',
        'WEAPON_ProximityMine', 'WEAPON_BZGas', 'WEAPON_Molotov', 'WEAPON_FireExtinguisher',
        'WEAPON_PetrolCan', 'WEAPON_Flare', 'WEAPON_Ball', 'WEAPON_Snowball', 'WEAPON_SmokeGrenade'
    }
}

function Shared.NormalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    local normalized = plate:upper():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if normalized == '' then return nil end
    return normalized
end

function Shared.GetPlateKey(plate)
    local normalized = Shared.NormalizePlate(plate)
    if not normalized then return nil end
    local plateKey = normalized:gsub('%W', '')
    if plateKey == '' then return nil end
    return plateKey
end

function Shared.GetVehicleIdentity(vehicle, ownerSource)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local plate = Shared.NormalizePlate(GetVehicleNumberPlateText(vehicle))
    local plateKey = Shared.GetPlateKey(plate)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    return {
        entity = vehicle,
        netId = netId > 0 and netId or nil,
        plate = plate,
        plateKey = plateKey,
        model = GetEntityModel(vehicle),
        ownerSource = ownerSource
    }
end

function Shared.DebugPrint(message, ...)
    if not Shared.debug.enabled then return end
    local formatted = select('#', ...) > 0 and message:format(...) or message
    print(('[mri_Qcarkeys] %s'):format(formatted))
end

Shared.dispatch = { event = Shared.alert.dispatchEvent }
Shared.luxuryClasses = Shared.alert.silentClasses
Shared.NPCHasGunChance = Shared.steal.armedNpcChance
Shared.GrabKeysOnDriverChance = 0.45
Shared.ignition.failDamageMin = Shared.ignition.lockpickFailDamage
Shared.ignition.failDamageMax = Shared.ignition.hotwireFailDamage
