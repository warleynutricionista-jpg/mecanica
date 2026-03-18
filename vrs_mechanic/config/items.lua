Config = Config or {}

-- ============================================================
-- MATERIAIS NECESSÁRIOS POR TIPO DE REPARO
-- ============================================================
Config.RepairMaterials = {
    engine = {
        { item = 'engine_parts',  amount = 2 },
        { item = 'scrap_metal',   amount = 1 },
    },
    body = {
        { item = 'plastic',       amount = 2 },
        { item = 'scrap_metal',   amount = 1 },
    },
    oil = {
        { item = 'oil_can',       amount = 1 },
    },
    radiator = {
        { item = 'radiator_parts', amount = 1 },
        { item = 'coolant',        amount = 1 },
    },
    brakes = {
        { item = 'brake_pads',    amount = 2 },
        { item = 'copper',        amount = 1 },
    },
    clutch = {
        { item = 'clutch_kit',    amount = 1 },
    },
    axle = {
        { item = 'axle_parts',    amount = 1 },
        { item = 'steel',         amount = 1 },
    },
    battery = {
        { item = 'battery',       amount = 1 },
    },
    suspension = {
        { item = 'suspension_parts', amount = 1 },
        { item = 'steel',            amount = 1 },
    },
    transmission = {
        { item = 'transmission_parts', amount = 1 },
        { item = 'steel',              amount = 1 },
    },
    fuel_tank = {
        { item = 'steel',         amount = 2 },
        { item = 'plastic',       amount = 1 },
    },
    tyre = {
        { item = 'spare_tyre',    amount = 1 },
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
        { item = 'mechanic_toolbox',  amount = 0 }, -- não consome, apenas verifica
    },
    engine_v8 = {
        { item = 'engine_upgrade_v8', amount = 1 },
        { item = 'mechanic_toolbox',  amount = 0 },
    },
    turbo = {
        { item = 'turbo_kit',         amount = 1 },
    },
    ecu_stage1 = {
        { item = 'ecu_stage_1',       amount = 1 },
    },
    ecu_stage2 = {
        { item = 'ecu_stage_2',       amount = 1 },
    },
    nitrous = {
        { item = 'nitrous_tank',      amount = 1 },
    },
    brakes_sport = {
        { item = 'brake_pads',        amount = 4 },
        { item = 'steel',             amount = 2 },
    },
    suspension_sport = {
        { item = 'suspension_parts',  amount = 2 },
        { item = 'steel',             amount = 2 },
    },
}

-- ============================================================
-- ITENS DE OFICINA (para ox_inventory)
-- Referência para criar os itens no banco de dados do inventário
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
