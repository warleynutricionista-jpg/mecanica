Config = {}

Config.Debug = false
Config.Locale = 'pt-br'
Config.MechanicJob = 'mechanic'
Config.MinBossGrade = 3
Config.RequireDuty = true
Config.MaxServiceDistance = 6.0
Config.FallbackUseZones = true
Config.UseOxTarget = true
Config.UseRadialBlips = true
Config.EnableStash = true

Config.Cooldowns = {
    service = 15,
    serviceVehicle = 30,
    duty = 3,
    menu = 2,
    admin = 5
}

Config.Stash = {
    id = 'bakitelli_mechanic_stash',
    label = 'Mechanic Storage',
    slots = 200,
    weight = 1500000,
    owner = false,
    groups = { mechanic = 0 }
}

Config.Stations = {
    {
        label = 'Bennys Downtown',
        blip = vec3(-211.55, -1324.55, 30.89),
        duty = vec3(-206.90, -1332.20, 30.89),
        stash = vec3(-196.20, -1318.05, 31.09),
        garage = vec4(-188.12, -1290.76, 31.30, 269.50),
        service = vec3(-211.55, -1324.55, 30.89)
    }
}

Config.ServiceVehicles = {
    flatbed = 'Flatbed',
    towtruck = 'Towtruck',
    utillitruck3 = 'Utility Truck'
}

Config.Services = {
    repair = {
        label = 'Repair Vehicle',
        icon = 'wrench',
        duration = 9000,
        requiresItem = { name = 'repairkit', count = 1 },
        cooldown = 20
    },
    clean = {
        label = 'Clean Vehicle',
        icon = 'soap',
        duration = 5000,
        requiresItem = nil,
        cooldown = 10
    }
}
