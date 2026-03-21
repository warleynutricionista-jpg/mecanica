Config = Config or {}

Config.UseTarget = true
Config.SprayModel = 'prop_tool_nailgun'
Config.PaintDuration = 12000
Config.SessionTimeout = 180
Config.SessionHeartbeatInterval = 15
Config.ReleaseDistance = 30.0
Config.DefaultVehicleRadius = 3.2
Config.DefaultControlRadius = 1.6
Config.AllowedJobsFallback = { 'mechanic' }
Config.Debug = false

Config.UI = {
    Title = 'Cabine de Pintura',
    Subtitle = 'Sistema premium de repintura automotiva',
    Icon = 'spray-can-sparkles',
    Position = 'top-right',
    PreviewEnabledByDefault = true,
    SessionBreakDistance = 25.0,
    ProgressLabel = 'Aplicando pintura premium...',
    ControlHelp = '[E] Abrir cabine de pintura',
    BusyHelp = 'Cabine ocupada no momento.',
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
    Sounds = {
        enabled = true,
        start = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        success = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
        cancel = { name = 'BACK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        error = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    },
    Confirmation = {
        centered = true,
        confirmLabel = 'Iniciar pintura',
        cancelLabel = 'Voltar',
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
        candidates = {
            { dict = 'scr_playerlamgraff', name = 'scr_lamgraff_paint_spray', scale = 1.35, alpha = 0.95 },
            { dict = 'scr_carwash', name = 'ent_amb_car_wash_jet_soap', scale = 0.5, alpha = 0.55 },
            { dict = 'core', name = 'ent_sht_petrol', scale = 0.85, alpha = 0.7 },
            { dict = 'core', name = 'ent_amb_steam', scale = 1.0, alpha = 0.85 },
        },
    },
    Impact = {
        candidates = {
            { dict = 'core', name = 'veh_respray_smoke', scale = 0.45, alpha = 0.45 },
            { dict = 'scr_paintnspray', name = 'scr_respray_smoke', scale = 0.35, alpha = 0.35 },
        },
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
            -- Esquerda
            { pos = vec3(-3087.02, 421.49, 8.33), rotation = vec3(0.0, 25.0, 80.0), scale = 1.2 },
            { pos = vec3(-3088.45, 422.18, 8.33), rotation = vec3(0.0, 25.0, 80.0), scale = 1.2 },
            { pos = vec3(-3089.95, 422.90, 8.33), rotation = vec3(0.0, 25.0, 80.0), scale = 1.2 },
            -- Direira
            { pos = vec3(-3087.78, 426.70, 8.33), rotation = vec3(0.0, 25.0, -80), scale = 1.2 },
            { pos = vec3(-3086.40, 426.04, 8.33), rotation = vec3(1.074, 25.568, -80), scale = 1.2 },
            { pos = vec3(-3085.04, 425.38, 8.33), rotation = vec3(-0.875, 24.862, -80), scale = 1.2 },
        },
        previewCam = {
            coords = vec4(-3082.55, 419.61, 8.92, 53.0),
            pointAt = vec3(-3087.05, 423.91, 7.35),
        },
        blip = false,
    },
}

