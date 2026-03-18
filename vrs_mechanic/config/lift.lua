Config = Config or {}

Config.Lift = Config.Lift or {}

Config.Lift.MinHeight = 0.0
Config.Lift.MaxHeight = 1.2
Config.Lift.StepHeight = 0.15
Config.Lift.MoveSpeed = 0.18
Config.Lift.DefaultWorkHeights = {
    engine = 0.45,
    wheel = 0.55,
    underbody = 1.0,
    reset = 0.0,
}

Config.Lift.snapDistance = Config.Lift.snapDistance or 5.0
Config.Lift.exitOffset = Config.Lift.exitOffset or vec3(3.0, 0.0, 0.0)
Config.Lift.maxDistance = Config.Lift.maxDistance or 12.0
Config.Lift.requireVehicleToRaise = Config.Lift.requireVehicleToRaise ~= false
Config.Lift.positionTolerance = Config.Lift.positionTolerance or 0.02
Config.Lift.minMoveDuration = Config.Lift.minMoveDuration or 900
Config.Lift.controlPanelDistance = Config.Lift.controlPanelDistance or 1.6
Config.Lift.controlPanelSize = Config.Lift.controlPanelSize or vec3(0.45, 0.55, 1.6)
Config.Lift.controlPanelOffset = Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0)
Config.Lift.savedPresetFile = Config.Lift.savedPresetFile or 'lift_presets.json'
Config.Lift.levels = {
    { label = 'Base', zOffset = Config.Lift.MinHeight },
    { label = 'Serviço', zOffset = Config.Lift.DefaultWorkHeights.wheel },
    { label = 'Inferior', zOffset = Config.Lift.DefaultWorkHeights.underbody },
}
