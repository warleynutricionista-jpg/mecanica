Config = Config or {}

Config.ServicePositionPresets = {
    front_center = { offset = vec3(0.0, 2.4, 0.0), heading = 180.0 },
    rear_center = { offset = vec3(0.0, -2.4, 0.0), heading = 0.0 },
    left_side = { offset = vec3(-1.6, 0.25, 0.0), heading = 90.0 },
    right_side = { offset = vec3(1.6, 0.25, 0.0), heading = -90.0 },
    underbody_left = { offset = vec3(-0.9, 0.1, 0.0), heading = 90.0 },
    underbody_right = { offset = vec3(0.9, 0.1, 0.0), heading = -90.0 },
    engine_front = { offset = vec3(0.0, 2.15, 0.0), heading = 180.0 },
    trunk_rear = { offset = vec3(0.0, -2.1, 0.0), heading = 0.0 },
}

Config.ServiceContexts = {
    diagnostic = {
        quick = {
            serviceArea = 'front_section',
            positionPreset = 'front_center',
            animationSet = 'diagnostic',
            duration = 2500,
        },
        full = {
            serviceArea = 'front_section',
            positionPreset = 'front_center',
            animationSet = 'diagnostic',
            duration = 3000,
            requiresHoodOpen = true,
        },
    },
    repair = {
        engine = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'engine_work',
        },
        oil = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'engine_work',
        },
        radiator = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'engine_work',
        },
        battery = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'engine_work',
        },
        brakes = {
            serviceArea = 'wheel',
            positionPreset = 'nearest_wheel',
            animationSet = 'wheel_work',
            preferredLiftHeight = 0.55,
        },
        suspension = {
            serviceArea = 'wheel',
            positionPreset = 'nearest_wheel',
            animationSet = 'wheel_work',
            requiresLift = true,
            minimumLiftHeight = 0.55,
        },
        clutch = {
            serviceArea = 'underbody',
            positionPreset = 'underbody_side',
            requiresLift = true,
            minimumLiftHeight = 1.05,
            animationSet = 'underbody_work',
        },
        axle = {
            serviceArea = 'underbody',
            positionPreset = 'underbody_side',
            requiresLift = true,
            minimumLiftHeight = 1.0,
            animationSet = 'underbody_work',
        },
        transmission = {
            serviceArea = 'underbody',
            positionPreset = 'underbody_side',
            requiresLift = true,
            minimumLiftHeight = 1.1,
            animationSet = 'underbody_work',
        },
        fuel_tank = {
            serviceArea = 'rear_section',
            positionPreset = 'trunk_rear',
            requiresLift = true,
            minimumLiftHeight = 0.85,
            animationSet = 'underbody_work',
        },
        body = {
            serviceArea = 'lateral',
            positionPreset = 'nearest_side',
            animationSet = 'body_work',
        },
        tyre = {
            serviceArea = 'wheel',
            positionPreset = 'specific_wheel',
            animationSet = 'wheel_work',
        },
        cleaning = {
            serviceArea = 'exterior',
            positionPreset = 'nearest_side',
            animationSet = 'cleaning',
            duration = 9000,
        },
    },
    upgrade = {
        engine_v6 = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'upgrade_install',
        },
        engine_v8 = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'upgrade_install',
        },
        turbo = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'upgrade_install',
        },
        ecu_stage1 = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'upgrade_install',
        },
        ecu_stage2 = {
            serviceArea = 'engine',
            positionPreset = 'engine_front',
            requiresHoodOpen = true,
            animationSet = 'upgrade_install',
        },
        nitrous = {
            serviceArea = 'rear_section',
            positionPreset = 'trunk_rear',
            requiresTrunkOpen = true,
            animationSet = 'upgrade_install',
        },
        brakes_sport = {
            serviceArea = 'wheel',
            positionPreset = 'nearest_wheel',
            animationSet = 'wheel_work',
            preferredLiftHeight = 0.55,
        },
        suspension_sport = {
            serviceArea = 'underbody',
            positionPreset = 'underbody_side',
            requiresLift = true,
            minimumLiftHeight = 1.0,
            animationSet = 'underbody_work',
        },
    },
}
