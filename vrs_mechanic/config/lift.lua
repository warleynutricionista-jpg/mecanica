Config = Config or {}

Config.Lift = Config.Lift or {}

-- ============================================================
-- MODELOS DE PROPS (baseado no mh-carlift)
-- ============================================================
Config.Lift.PlatformModel = 'prop_spray_jackframe'
Config.Lift.PoleModel = 'prop_spray_jackleg'
Config.Lift.ElecBoxModel = 'prop_elecbox_02b'

-- ============================================================
-- SPAWNING DE PROPS
-- ============================================================
Config.Lift.SpawnPoles = true
Config.Lift.SpawnElecBox = true
Config.Lift.PoleZOffset = -0.30
Config.Lift.ElecBoxOffset = vec3(0.0, -3.3, -0.7)

-- ============================================================
-- VELOCIDADES DE MOVIMENTO
-- ============================================================
Config.Lift.SpeedUp = 0.0012
Config.Lift.SpeedDown = 0.0018
Config.Lift.SpeedSlow = 0.0006
Config.Lift.SlowZoneSize = 0.15
Config.Lift.MovementTimeoutMs = 20000

-- ============================================================
-- ALTURAS (offsets relativos a partir da base)
-- ============================================================
Config.Lift.MinHeight = 0.0
Config.Lift.MaxHeight = 2.1
Config.Lift.VehicleZOffset = 0.36

Config.Lift.DefaultWorkHeights = {
    engine = 0.45,
    wheel = 0.55,
    underbody = 1.0,
    reset = 0.0,
}

-- ============================================================
-- VEÍCULO E INTERAÇÃO
-- ============================================================
Config.Lift.snapDistance = 5.0
Config.Lift.exitOffset = vec3(3.0, 0.0, 0.0)
Config.Lift.maxDistance = 12.0
Config.Lift.requireVehicleToRaise = true

-- ============================================================
-- PAINEL DE CONTROLE
-- ============================================================
Config.Lift.controlPanelDistance = 2.5
Config.Lift.controlPanelSize = vec3(0.6, 0.6, 1.8)
Config.Lift.controlPanelOffset = vec3(1.9, 0.0, 0.0)

-- ============================================================
-- NÍVEIS PREDEFINIDOS
-- ============================================================
Config.Lift.levels = {
    { label = 'Base', zOffset = Config.Lift.MinHeight },
    { label = 'Serviço', zOffset = Config.Lift.DefaultWorkHeights.wheel },
    { label = 'Inferior', zOffset = Config.Lift.DefaultWorkHeights.underbody },
    { label = 'Máximo', zOffset = Config.Lift.MaxHeight },
}

-- ============================================================
-- PERMISSÕES
-- ============================================================
Config.Lift.requireDuty = true
Config.Lift.AdminAce = 'group.admin' -- ACE opcional para permitir gestão total dos elevadores
Config.Lift.AdminRequireDuty = true

-- ============================================================
-- ADMIN / EDIÇÃO IN-GAME
-- ============================================================
Config.Lift.DefaultModelName = 'standard_lift'
Config.Lift.LayoutFile = 'lift_layouts.json'
Config.Lift.AdminCommand = 'liftadmin'
Config.Lift.MinSpacing = 4.0
Config.Lift.ValidationDistanceFromShop = 35.0
Config.Lift.MaxGroundDelta = 0.45

Config.Lift.DebugCommand = 'liftdebug'
Config.Lift.WorldDetection = {
    enabled = true,
    discoverOnStart = true,
    discoverOnZoneEnter = true,
    scanCooldownMs = 10000,
    maxDistanceFromShop = 45.0,
    maxObjectsPerScan = 2048,
    dedupeDistance = 1.5,
}

-- ============================================================
-- REGISTRO UNIVERSAL DE MODELOS
-- ============================================================
Config.Lift.ModelDefaults = {
    label = 'Elevador genérico',
    family = 'generic',
    sourceType = 'world',
    useExistingEntity = true,
    minHeight = Config.Lift.MinHeight,
    maxHeight = Config.Lift.MaxHeight,
    vehicleOffset = vec3(0.0, 0.0, Config.Lift.VehicleZOffset),
    platformOffset = vec3(0.0, 0.0, 0.0),
    interactionOffset = Config.Lift.controlPanelOffset,
    length = 5.0,
    width = 2.5,
    fallbackToModelDimensions = true,
}

Config.Lift.Models = {
    standard_lift = {
        model = 'standard_lift',
        label = 'Elevador padrão VRS',
        family = 'two_post',
        sourceType = 'spawned_composite',
        useExistingEntity = false,
        platformModel = Config.Lift.PlatformModel,
        poleModel = Config.Lift.PoleModel,
        elecBoxModel = Config.Lift.ElecBoxModel,
        spawnPoles = true,
        spawnElecBox = true,
        platformOffset = vec3(0.0, 0.0, 0.0),
        vehicleOffset = vec3(0.0, 0.0, Config.Lift.VehicleZOffset),
        interactionOffset = Config.Lift.controlPanelOffset,
        minHeight = Config.Lift.MinHeight,
        maxHeight = Config.Lift.MaxHeight,
        length = 5.0,
        width = 2.5,
    },
    prop_spray_jackframe = {
        model = 'prop_spray_jackframe',
        label = 'Spray Jack Frame',
        family = 'platform',
        sourceType = 'world_or_spawned',
        useExistingEntity = true,
        vehicleOffset = vec3(0.0, 0.0, 0.36),
        interactionOffset = vec3(1.8, 0.0, 0.0),
        minHeight = 0.0,
        maxHeight = 2.1,
        length = 5.0,
        width = 2.5,
    },
    imp_prop_impexp_carlift_01a = {
        model = 'imp_prop_impexp_carlift_01a',
        label = 'Import/Export Lift 01A',
        family = 'two_post',
        sourceType = 'world',
        useExistingEntity = true,
        vehicleOffset = vec3(0.0, 0.0, 0.5),
        interactionOffset = vec3(2.0, 0.0, 0.0),
        minHeight = 0.0,
        maxHeight = 2.5,
        length = 5.4,
        width = 2.8,
    },
    imp_prop_impexp_carlift_02a = {
        model = 'imp_prop_impexp_carlift_02a',
        label = 'Import/Export Lift 02A',
        family = 'two_post',
        sourceType = 'world',
        useExistingEntity = true,
        vehicleOffset = vec3(0.0, 0.0, 0.5),
        interactionOffset = vec3(2.0, 0.0, 0.0),
        minHeight = 0.0,
        maxHeight = 2.5,
        length = 5.6,
        width = 2.9,
    },
    imp_prop_impexp_carlift = {
        model = 'imp_prop_impexp_carlift',
        label = 'Import/Export Lift',
        family = 'two_post',
        sourceType = 'world',
        useExistingEntity = true,
        vehicleOffset = vec3(0.0, 0.0, 0.5),
        interactionOffset = vec3(2.0, 0.0, 0.0),
        minHeight = 0.0,
        maxHeight = 2.5,
        length = 5.6,
        width = 2.9,
    },
    imp_prop_impexp_carlifts = {
        model = 'imp_prop_impexp_carlifts',
        label = 'Import/Export Lift Cluster',
        family = 'four_post',
        sourceType = 'world',
        useExistingEntity = true,
        vehicleOffset = vec3(0.0, 0.0, 0.45),
        interactionOffset = vec3(2.4, 0.0, 0.0),
        minHeight = 0.0,
        maxHeight = 2.3,
        length = 5.8,
        width = 3.2,
    },
}

Config.Lift.Editor = {
    moveSpeed = 0.03,
    fineMoveSpeed = 0.01,
    verticalSpeed = 0.02,
    rotationSpeed = 1.5,
    previewAlpha = 170,
    refreshInterval = 150,
}

-- ============================================================
-- PERSISTÊNCIA
-- ============================================================
Config.Lift.savedPresetFile = 'lift_presets.json'
