Config = Config or {}

-- ============================================================
-- HUB F12 - CONFIGURAÇÃO DO PAINEL CENTRAL DA MECÂNICA
-- ============================================================

Config.Panel = {
    -- Tecla principal de acesso
    key = 'F12',
    description = 'HUB Mecânica',

    -- Job permitido (pode ser string ou table de jobs)
    jobs = { 'mechanic', 'mechanic2' },

    -- Exigir duty para abrir o HUB
    requireDuty = true,

    -- Cooldown entre aberturas (ms)
    openCooldown = 500,

    -- Permitir abrir dentro de veículo
    allowInVehicle = false,

    -- Permitir abrir fora da oficina (com opções reduzidas)
    allowOutsideShop = true,

    -- Permitir gestão fora da oficina
    allowManagementOutsideShop = false,

    -- Comportamento do F12 com tablet já aberto: 'close' ou 'toggle_hub'
    tabletToggleBehavior = 'close',

    -- Bloquear quando pause menu estiver ativo
    blockOnPauseMenu = true,

    -- Bloquear quando inventário/chat estiver com foco
    blockOnNuiFocus = true,
}

-- ============================================================
-- PERMISSÕES POR GRADE
-- ============================================================

Config.PanelAccess = {
    -- Grades que podem acessar gestão (funcionários, preços, logs)
    managementGrades = { 3, 4, 5 },

    -- Grades de boss/proprietário (acesso total + configurações)
    bossGrades = { 5 },

    -- Painéis disponíveis por nível de acesso
    -- 'basic'   = mecânico comum (grade 0-2)
    -- 'manager' = gerente (grade 3-4)
    -- 'boss'    = proprietário (grade 5)
    panels = {
        basic = {
            'tablet',
            'diagnostic',
            'work_orders',
            'billing',
            'quick_services',
        },
        manager = {
            'tablet',
            'diagnostic',
            'work_orders',
            'billing',
            'quick_services',
            'employees',
            'stash',
        },
        boss = {
            'tablet',
            'diagnostic',
            'work_orders',
            'billing',
            'quick_services',
            'employees',
            'management',
            'stash',
            'settings',
        },
    },
}
