Config = Config or {}

Config.UseTarget = true
Config.SprayModel = 'prop_tool_nailgun'
Config.PaintDuration = 9000
Config.SessionTimeout = 180
Config.ReleaseDistance = 30.0
Config.DefaultVehicleRadius = 3.2
Config.DefaultControlRadius = 1.6
Config.AllowedJobsFallback = { 'mechanic' }
Config.Debug = false

Config.UI = {
    Title = 'Cabine de Pintura',
    Icon = 'spray-can-sparkles',
    Position = 'top-right',
    PreviewEnabledByDefault = true,
    SessionBreakDistance = 25.0,
    ProgressLabel = 'Aplicando pintura premium...',
    Marker = {
        type = 27,
        scale = vec3(1.25, 1.25, 0.45),
        color = { r = 84, g = 174, b = 255, a = 180 },
    },
    Camera = {
        enabled = true,
        fov = 42.0,
        easeTime = 600,
    },
}

Config.FinishTypes = {
    { value = 0, key = 'normal', label = 'Normal', description = 'Acabamento clássico com brilho padrão.' },
    { value = 1, key = 'metallic', label = 'Metálico', description = 'Brilho profundo com reflexo refinado.' },
    { value = 2, key = 'pearlescent', label = 'Perolado', description = 'Reflexo premium com nuance perolada.' },
    { value = 3, key = 'matte', label = 'Fosco', description = 'Visual discreto, moderno e sem brilho.' },
    { value = 4, key = 'metal', label = 'Metalizado', description = 'Textura metálica mais intensa.' },
    { value = 5, key = 'chrome', label = 'Cromado', description = 'Acabamento espelhado e chamativo.' },
}

Config.Particles = {
    Spray = {
        dict = 'core',
        name = 'ent_amb_steam',
        scale = 1.0,
        alpha = 0.85,
    },
    FinishSmoke = {
        dict = 'scr_paintnspray',
        name = 'scr_respray_smoke',
        scale = 0.8,
        duration = 3500,
    },
}

Config.Locations = {
    {
        name = 'LS Customs - Cabine Superior',
        control = vec4(-3078.81, 422.45, 7.56, -15.79),
        vehicle = vec4(-3087.43, 424.4, 6.98, 70.0),
        radius = {
            control = 1.6,
            vehicle = 3.0,
        },
        jobs = { 'mechanic' },
        sprays = {
            { pos = vec3(-3088.12, 426.48, 6.99), rotation = vec3(0.0, 25.0, -111.817), scale = 1.2 },
            { pos = vec3(-3086.68, 425.76, 6.99), rotation = vec3(0.0, 25.0, -114.508), scale = 1.2 },
            { pos = vec3(-3085.14, 425.04, 6.99), rotation = vec3(0.0, 25.0, 70.213), scale = 1.2 },
            { pos = vec3(-3086.95, 421.74, 6.99), rotation = vec3(0.0, 25.0, 72.735), scale = 1.2 },
            { pos = vec3(-3087.99, 422.4, 6.99), rotation = vec3(1.074, 25.568, 161.155), scale = 1.2 },
            { pos = vec3(-3089.55, 422.99, 6.99), rotation = vec3(-0.875, 24.862, 160.072), scale = 1.2 },
        },
        previewCam = {
            coords = vec4(-3082.55, 419.61, 8.92, 53.0),
            pointAt = vec3(-3087.05, 423.91, 7.35),
        },
        blip = false,
    },
}
