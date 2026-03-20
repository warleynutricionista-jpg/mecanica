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
