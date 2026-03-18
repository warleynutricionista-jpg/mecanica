Config = Config or {}

-- ============================================================
-- OFICINAS
-- ============================================================
Config.Shops = {
    -- ========================================================
    -- OFICINA PRINCIPAL (OWNED) - LS Customs / Mecânica Central
    -- ========================================================
    ['mecanica_central'] = {
        label = 'Mecânica Central',
        type = 'owned', -- 'owned' ou 'self-service'
        job = 'mechanic',
        managementGrades = { 3, 4 }, -- grades que podem gerenciar
        logo = 'wrench',

        blip = {
            enabled = true,
            sprite = 446,
            color = 0,
            scale = 0.7,
            label = 'Mecânica Central',
        },

        -- Zona principal da oficina
        zones = {
            main = {
                coords = vec3(-339.0, -130.0, 39.0),
                size = vec3(30.0, 30.0, 5.0),
                rotation = 340.0,
            },
        },

        -- Pontos de elevador / serviço
        lifts = {
            {
                coords = vec4(-340.95, -128.24, 39.0, 160.0),
                length = 5.0,
                width = 2.5,
                controlPanel = vec4(-339.05, -129.09, 39.01, 71.44),
            },
            {
                coords = vec4(-336.88, -131.56, 39.0, 160.0),
                length = 5.0,
                width = 2.5,
            },
        },

        -- Pontos de interação
        locations = {
            duty = vec3(-323.30, -128.79, 39.02),
            stash = vec3(-319.19, -131.90, 37.98),
            shop = vec3(-320.50, -129.00, 39.00),
            tablet = vec3(-322.00, -127.00, 39.00),
        },

        partsShop = {
            public = false,
            jobOnly = true,
            allowTabletAccess = true,
        },

        -- Stash de oficina
        stash = {
            slots = 50,
            weight = 100000,
        },

        -- Preços base (podem ser sobrescritos por management)
        basePrices = {
            engine      = 5000,
            body        = 3000,
            oil         = 500,
            radiator    = 2000,
            brakes      = 1500,
            clutch      = 2500,
            axle        = 3000,
            battery     = 800,
            suspension  = 2000,
            transmission = 4000,
            fuel_tank   = 1500,
            tyre        = 600,
        },

        -- Serviços disponíveis
        services = {
            diagnostic = true,
            repair = true,
            oil_change = true,
            upgrades = true,
            tyre_change = true,
            wash = true,
        },
    },

    -- ========================================================
    -- OFICINA SECUNDÁRIA (OWNED) - Harmony
    -- ========================================================
    ['harmony'] = {
        label = 'Oficina Harmony',
        type = 'owned',
        job = 'mechanic2',
        managementGrades = { 3, 4 },
        logo = 'wrench',

        blip = {
            enabled = true,
            sprite = 446,
            color = 47,
            scale = 0.7,
            label = 'Oficina Harmony',
        },

        zones = {
            main = {
                coords = vec3(1175.0, 2640.0, 37.75),
                size = vec3(25.0, 25.0, 5.0),
                rotation = 0.0,
            },
        },

        lifts = {
            {
                coords = vec4(1175.0, 2640.0, 37.75, 0.0),
                length = 5.0,
                width = 2.5,
            },
        },

        locations = {
            duty = vec3(1182.0, 2645.0, 37.75),
            stash = vec3(1180.0, 2638.0, 37.75),
            shop = vec3(1178.0, 2643.0, 37.75),
            tablet = vec3(1181.2, 2641.8, 37.75),
        },

        partsShop = {
            public = false,
            jobOnly = true,
            allowTabletAccess = true,
        },

        stash = {
            slots = 40,
            weight = 80000,
        },

        basePrices = {
            engine      = 4500,
            body        = 2500,
            oil         = 400,
            radiator    = 1800,
            brakes      = 1200,
            clutch      = 2200,
            axle        = 2500,
            battery     = 700,
            suspension  = 1800,
            transmission = 3500,
            fuel_tank   = 1200,
            tyre        = 500,
        },

        services = {
            diagnostic = true,
            repair = true,
            oil_change = true,
            upgrades = true,
            tyre_change = true,
            wash = false,
        },
    },

    -- ========================================================
    -- OFICINA PÚBLICA (SELF-SERVICE)
    -- ========================================================
    ['autoservice'] = {
        label = 'Auto Serviço',
        type = 'self-service',
        job = nil, -- qualquer um pode usar
        logo = 'car',

        blip = {
            enabled = true,
            sprite = 446,
            color = 3,
            scale = 0.6,
            label = 'Auto Serviço',
        },

        zones = {
            main = {
                coords = vec3(537.0, -183.0, 54.5),
                size = vec3(20.0, 20.0, 5.0),
                rotation = 0.0,
            },
        },

        lifts = {
            {
                coords = vec4(537.0, -183.0, 54.5, 0.0),
                length = 5.0,
                width = 2.5,
            },
        },

        locations = {
            shop = vec3(537.0, -183.0, 54.5),
        },

        partsShop = {
            public = true,
            jobOnly = false,
            allowTabletAccess = false,
        },

        stash = nil, -- sem stash em self-service

        basePrices = {
            engine      = 8000,
            body        = 5000,
            oil         = 800,
            radiator    = 3500,
            brakes      = 2500,
            clutch      = 4000,
            axle        = 5000,
            battery     = 1200,
            suspension  = 3500,
            transmission = 6000,
            fuel_tank   = 2500,
            tyre        = 1000,
        },

        services = {
            diagnostic = true,
            repair = true,
            oil_change = true,
            upgrades = false,
            tyre_change = true,
            wash = false,
        },
    },
}
