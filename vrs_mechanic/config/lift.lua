Config = Config or {}

Config.Lift = Config.Lift or {}

Config.Lift.MinHeight = 0.0
Config.Lift.MaxHeight = 1.35
Config.Lift.StepHeight = 0.15
Config.Lift.MoveSpeed = 0.15
Config.Lift.AllowManualArrowControl = true
Config.Lift.DefaultWorkHeights = {
    engine = 0.45,
    wheel = 0.55,
    underbody = 1.15,
    reset = 0.0,
}

Config.Lift.snapDistance = Config.Lift.snapDistance or 5.0
Config.Lift.exitOffset = Config.Lift.exitOffset or vec3(3.0, 0.0, 0.0)
Config.Lift.moveDuration = Config.Lift.moveDuration or 3500
Config.Lift.maxDistance = Config.Lift.maxDistance or 12.0
Config.Lift.requireVehicleToRaise = Config.Lift.requireVehicleToRaise ~= false
Config.Lift.levels = {
    { label = 'Base', zOffset = Config.Lift.MinHeight },
    { label = 'Serviço', zOffset = Config.Lift.DefaultWorkHeights.wheel },
    { label = 'Inferior', zOffset = Config.Lift.DefaultWorkHeights.underbody },
}
