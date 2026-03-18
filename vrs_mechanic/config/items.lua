Config = Config or {}

-- ============================================================
-- MATERIAIS NECESSÁRIOS POR TIPO DE REPARO
-- ============================================================
Config.RepairMaterials = {
    engine = {
        { item = 'engine_parts', amount = 2 },
        { item = 'scrap_metal', amount = 1 },
    },
    body = {
        { item = 'plastic', amount = 2 },
        { item = 'scrap_metal', amount = 1 },
    },
    oil = {
        { item = 'oil_can', amount = 1 },
    },
    radiator = {
        { item = 'radiator_parts', amount = 1 },
        { item = 'coolant', amount = 1 },
    },
    brakes = {
        { item = 'brake_pads', amount = 2 },
        { item = 'copper', amount = 1 },
    },
    clutch = {
        { item = 'clutch_kit', amount = 1 },
    },
    axle = {
        { item = 'axle_parts', amount = 1 },
        { item = 'steel', amount = 1 },
    },
    battery = {
        { item = 'battery', amount = 1 },
    },
    suspension = {
        { item = 'suspension_parts', amount = 1 },
        { item = 'steel', amount = 1 },
    },
    transmission = {
        { item = 'transmission_parts', amount = 1 },
        { item = 'steel', amount = 1 },
    },
    fuel_tank = {
        { item = 'steel', amount = 2 },
        { item = 'plastic', amount = 1 },
    },
    tyre = {
        { item = 'spare_tyre', amount = 1 },
    },
}

-- ============================================================
-- MATERIAIS PARA REPARO DE RUA (kit básico)
-- ============================================================
Config.StreetRepairItems = {
    { item = 'repairkit_basic', amount = 1 },
}

-- ============================================================
-- MATERIAIS PARA UPGRADES
-- ============================================================
Config.UpgradeMaterials = {
    engine_v6 = {
        { item = 'engine_upgrade_v6', amount = 1 },
        { item = 'mechanic_toolbox', amount = 0 },
    },
    engine_v8 = {
        { item = 'engine_upgrade_v8', amount = 1 },
        { item = 'mechanic_toolbox', amount = 0 },
    },
    turbo = {
        { item = 'turbo_kit', amount = 1 },
    },
    ecu_stage1 = {
        { item = 'ecu_stage_1', amount = 1 },
    },
    ecu_stage2 = {
        { item = 'ecu_stage_2', amount = 1 },
    },
    nitrous = {
        { item = 'nitrous_tank', amount = 1 },
    },
    brakes_sport = {
        { item = 'brake_pads', amount = 4 },
        { item = 'steel', amount = 2 },
    },
    suspension_sport = {
        { item = 'suspension_parts', amount = 2 },
        { item = 'steel', amount = 2 },
    },
}

-- ============================================================
-- LOJA DE PEÇAS
-- ============================================================
Config.PartsShop = {
    enabled = true,
    currency = 'cash', -- cash/money = carteira | bank = banco
    defaultPublic = false,
    requireDutyForWorkshopOnly = true,
    maxPurchaseQuantity = 20,
    categories = {
        engine = {
            label = 'Motor',
            description = 'Peças de desempenho, velas, kits de motor e componentes internos.',
            icon = '⚙️',
        },
        brakes = {
            label = 'Freios',
            description = 'Pastilhas, discos e itens críticos de segurança.',
            icon = '🛑',
        },
        radiator = {
            label = 'Radiador',
            description = 'Arrefecimento, mangueiras e fluídos térmicos.',
            icon = '🌡️',
        },
        suspension = {
            label = 'Suspensão',
            description = 'Molas, amortecedores e kits de estabilidade.',
            icon = '🛞',
        },
        transmission = {
            label = 'Transmissão',
            description = 'Engrenagens, câmbio, eixo cardã e diferencial.',
            icon = '🔩',
        },
        clutch = {
            label = 'Embreagem',
            description = 'Kits completos para troca e manutenção fina.',
            icon = '🧰',
        },
        axle = {
            label = 'Eixo',
            description = 'Semi-eixos, juntas e materiais estruturais.',
            icon = '🪓',
        },
        electrical = {
            label = 'Elétrica / Bateria',
            description = 'Baterias, fusíveis e componentes eletrônicos.',
            icon = '🔋',
        },
        fluids = {
            label = 'Óleo e Fluidos',
            description = 'Óleo, aditivos, fluído de freio e refrigeração.',
            icon = '🛢️',
        },
        tools = {
            label = 'Ferramentas',
            description = 'Ferramentas essenciais para a bancada e atendimentos.',
            icon = '🧰',
        },
        upgrades = {
            label = 'Upgrades',
            description = 'Preparação, ECUs e peças especiais.',
            icon = '🚀',
        },
        nitrous = {
            label = 'Nitrous',
            description = 'Módulos e recargas para sistemas de nitro.',
            icon = '💨',
            enabled = true,
        },
    },
    items = {
        engine_parts = {
            label = 'Peças de Motor',
            category = 'engine',
            description = 'Conjunto básico para manutenção de motor.',
            price = 1850,
            stock = 40,
            icon = '⚙️',
        },
        radiator_parts = {
            label = 'Peças de Radiador',
            category = 'radiator',
            description = 'Kit de radiador para reparos e substituições.',
            price = 1450,
            stock = 30,
            icon = '🌡️',
        },
        brake_pads = {
            label = 'Pastilhas de Freio',
            category = 'brakes',
            description = 'Pastilhas reforçadas para manutenção diária.',
            price = 620,
            stock = 80,
            icon = '🛑',
        },
        clutch_kit = {
            label = 'Kit de Embreagem',
            category = 'clutch',
            description = 'Kit completo para troca de embreagem.',
            price = 2100,
            stock = 25,
            icon = '🧰',
        },
        axle_parts = {
            label = 'Peças de Eixo',
            category = 'axle',
            description = 'Componentes estruturais para eixo e transmissão.',
            price = 1560,
            stock = 30,
            icon = '🪓',
        },
        suspension_parts = {
            label = 'Peças de Suspensão',
            category = 'suspension',
            description = 'Molas e componentes para suspensão.',
            price = 1320,
            stock = 35,
            icon = '🛞',
        },
        transmission_parts = {
            label = 'Peças de Transmissão',
            category = 'transmission',
            description = 'Itens para manutenção de câmbio e transmissão.',
            price = 1890,
            stock = 25,
            icon = '🔩',
        },
        spare_tyre = {
            label = 'Pneu Sobressalente',
            category = 'suspension',
            description = 'Pneu pronto para troca rápida.',
            price = 720,
            stock = 30,
            icon = '🛞',
        },
        copper = {
            label = 'Cobre',
            category = 'electrical',
            description = 'Material condutor para reparos elétricos.',
            price = 180,
            stock = 150,
            icon = '🔌',
        },
        steel = {
            label = 'Aço',
            category = 'tools',
            description = 'Material estrutural e industrial.',
            price = 210,
            stock = 150,
            icon = '🪙',
        },
        plastic = {
            label = 'Plástico',
            category = 'tools',
            description = 'Material leve para acabamentos e suportes.',
            price = 90,
            stock = 150,
            icon = '🧱',
        },
        scrap_metal = {
            label = 'Sucata Metálica',
            category = 'tools',
            description = 'Material reaproveitado para reparos simples.',
            price = 75,
            stock = 200,
            icon = '♻️',
        },
        oil_can = {
            label = 'Lata de Óleo',
            category = 'fluids',
            description = 'Óleo lubrificante premium para oficina.',
            price = 260,
            stock = 60,
            icon = '🛢️',
        },
        coolant = {
            label = 'Fluido Refrigerante',
            category = 'fluids',
            description = 'Fluído de arrefecimento para motores.',
            price = 310,
            stock = 50,
            icon = '💧',
        },
        battery = {
            label = 'Bateria',
            category = 'electrical',
            description = 'Bateria automotiva de alta durabilidade.',
            price = 980,
            stock = 20,
            icon = '🔋',
        },
        repairkit_basic = {
            label = 'Kit de Reparo Básico',
            category = 'tools',
            description = 'Kit portátil para atendimentos rápidos.',
            price = 850,
            stock = 25,
            icon = '🧰',
        },
        repairkit_advanced = {
            label = 'Kit de Reparo Avançado',
            category = 'tools',
            description = 'Kit profissional para serviços completos.',
            price = 1650,
            stock = 20,
            icon = '🧰',
            workshopOnly = true,
        },
        mechanic_toolbox = {
            label = 'Caixa de Ferramentas',
            category = 'tools',
            description = 'Ferramenta obrigatória para upgrades avançados.',
            price = 2200,
            stock = 10,
            icon = '🧰',
            workshopOnly = true,
        },
        mechanic_tablet = {
            label = 'Tablet do Mecânico',
            category = 'tools',
            description = 'Dispositivo para gestão da oficina.',
            price = 3200,
            stock = 10,
            icon = '📱',
            workshopOnly = true,
        },
        cleaning_kit = {
            label = 'Kit de Limpeza',
            category = 'tools',
            description = 'Suprimentos para acabamento final.',
            price = 450,
            stock = 25,
            icon = '🧼',
        },
        engine_upgrade_v6 = {
            label = 'Upgrade de Motor V6',
            category = 'upgrades',
            description = 'Preparação intermediária para ganho de desempenho.',
            price = 8200,
            stock = 8,
            icon = '🚀',
            workshopOnly = true,
        },
        engine_upgrade_v8 = {
            label = 'Upgrade de Motor V8',
            category = 'upgrades',
            description = 'Preparação avançada para projetos especiais.',
            price = 12800,
            stock = 6,
            icon = '🚀',
            workshopOnly = true,
        },
        turbo_kit = {
            label = 'Kit Turbo',
            category = 'upgrades',
            description = 'Kit completo de indução forçada.',
            price = 9700,
            stock = 8,
            icon = '🚀',
            workshopOnly = true,
        },
        ecu_stage_1 = {
            label = 'ECU Estágio 1',
            category = 'upgrades',
            description = 'Reprogramação inicial da central.',
            price = 3500,
            stock = 10,
            icon = '💻',
            workshopOnly = true,
        },
        ecu_stage_2 = {
            label = 'ECU Estágio 2',
            category = 'upgrades',
            description = 'Mapeamento avançado para uso profissional.',
            price = 6100,
            stock = 8,
            icon = '💻',
            workshopOnly = true,
        },
        nitrous_tank = {
            label = 'Tanque de Nitro',
            category = 'nitrous',
            description = 'Cilindro pressurizado para sistemas nitrous.',
            price = 7600,
            stock = 5,
            icon = '💨',
            workshopOnly = true,
            requiresFeature = 'nitrous',
        },
    },
}

-- ============================================================
-- ITENS DE OFICINA (para ox_inventory)
-- ============================================================
--[[
    Lista de itens necessários no ox_inventory:

    KITS E FERRAMENTAS:
    - repairkit_basic       | Kit de Reparo Básico
    - repairkit_advanced    | Kit de Reparo Avançado
    - mechanic_toolbox      | Caixa de Ferramentas
    - mechanic_tablet       | Tablet do Mecânico
    - cleaning_kit          | Kit de Limpeza

    PEÇAS:
    - engine_parts          | Peças de Motor
    - radiator_parts        | Peças de Radiador
    - brake_pads            | Pastilhas de Freio
    - clutch_kit            | Kit de Embreagem
    - axle_parts            | Peças de Eixo
    - suspension_parts      | Peças de Suspensão
    - transmission_parts    | Peças de Transmissão
    - spare_tyre            | Pneu Sobressalente

    MATERIAIS:
    - copper                | Cobre
    - steel                 | Aço
    - plastic               | Plástico
    - scrap_metal           | Sucata Metálica
    - oil_can               | Lata de Óleo
    - coolant               | Fluido Refrigerante
    - battery               | Bateria

    UPGRADES:
    - engine_upgrade_v6     | Motor V6
    - engine_upgrade_v8     | Motor V8
    - turbo_kit             | Kit Turbo
    - ecu_stage_1           | ECU Estágio 1
    - ecu_stage_2           | ECU Estágio 2
    - nitrous_tank          | Tanque de Nitro
]]
