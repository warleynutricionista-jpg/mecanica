Config = Config or {}

-- ============================================================
-- LOCALES
-- ============================================================
Config.Locale = 'pt-br'
Config.DefaultLocale = 'pt-br'
Config.FallbackLocale = 'en'

-- ============================================================
-- STATUS MÁXIMO DE CADA SUBSISTEMA
-- ============================================================
Config.MaxStatus = {
    engine      = 1000.0,
    body        = 1000.0,
    oil         = 100.0,
    radiator    = 100.0,
    brakes      = 100.0,
    clutch      = 100.0,
    axle        = 100.0,
    battery     = 100.0,
    suspension  = 100.0,
    transmission = 100.0,
    fuel_tank   = 100.0,
}

-- ============================================================
-- DEGRADAÇÃO POR USO
-- ============================================================
Config.Degradation = {
    enabled = true,
    updateInterval = 10000, -- ms entre cada checagem de degradação

    -- Desgaste por distância percorrida (por km)
    distanceWear = {
        oil         = 0.15,
        brakes      = 0.08,
        suspension  = 0.04,
        clutch      = 0.05,
        transmission = 0.03,
    },

    -- Multiplicadores de dano por colisão (0-1, aplicado sobre impacto)
    collisionDamage = {
        body        = 1.0,
        radiator    = 0.6,
        axle        = 0.4,
        suspension  = 0.5,
        engine      = 0.3,
        battery     = 0.2,
        fuel_tank   = 0.15,
    },

    -- Efeitos cascata: óleo zerado danifica motor
    oilEngineMultiplier = 5.0, -- dano extra no motor quando óleo <= 0

    -- Freios ruins: capacidade de frenagem reduzida (0.0 = sem freio, 1.0 = normal)
    brakesMinEfficiency = 0.3,

    -- Radiador ruim: superaquecimento
    radiatorOverheatThreshold = 30, -- abaixo disso, motor superaquece
    radiatorEngineDamageRate = 2.0, -- dano/s no motor com radiador ruim

    -- Bateria ruim: chance de falha na ignição (%)
    batteryIgnitionFailChance = 50, -- quando battery_health < 20

    -- Transmissão ruim: perda de torque
    transmissionTorqueLoss = 0.4, -- máximo de perda (40%)
}

-- ============================================================
-- REPARO DE RUA VS OFICINA
-- ============================================================
Config.StreetRepair = {
    enabled = true,
    maxRecovery = 50.0, -- recuperação máxima (%) em reparo de rua
    allowedParts = { 'engine', 'body', 'oil', 'brakes', 'battery' },
    requireItem = 'repairkit_basic',
    skillCheck = { 'easy', 'easy', 'easy' },
    duration = 8000,
}

Config.ShopRepair = {
    requireJob = true,
    requireDuty = true,
    requireZone = true, -- precisa estar em zona de oficina
    skillCheck = { 'easy', 'medium', 'easy', 'medium' },
    duration = 12000,
}

-- ============================================================
-- SISTEMA DE ÓLEO
-- ============================================================
Config.OilSystem = {
    enabled = true,
    consumptionRate = 0.02, -- por km rodado
    warningThreshold = 20, -- % para aviso
    criticalThreshold = 5, -- % para dano ao motor
    engineDamageRate = 3.0, -- dano/s quando óleo crítico
}

-- ============================================================
-- VEÍCULOS IGNORADOS
-- ============================================================
Config.IgnoredVehicleClasses = {
    [8]  = true, -- motos (opcional, remova se quiser incluir)
    [13] = true, -- bicicletas
    [14] = true, -- barcos
    [15] = true, -- helicópteros
    [16] = true, -- aviões
    [21] = true, -- trens
}

-- ============================================================
-- COBRANÇA
-- ============================================================
Config.Billing = {
    enabled = true,
    minAmount = 100,
    maxAmount = 500000,
    maxDistance = 10.0, -- distância máxima para cobrar
    useSociety = true, -- usar conta society quando disponível
    employeeCommission = 0.15, -- 15% para o mecânico
}

-- ============================================================
-- ELEVADOR / ZONA DE SERVIÇO
-- ============================================================
-- Configuração completa do elevador está em config/lift.lua
-- Aqui só mantemos compatibilidade para referências externas
Config.Lift = Config.Lift or {}

-- ============================================================
-- UPGRADES
-- ============================================================
Config.Upgrades = {
    enabled = true,
    requireJob = true,
    requireDuty = true,
    requireZone = true,
    skillCheck = { 'medium', 'hard', 'medium', 'hard' },
    duration = 15000,
}

-- ============================================================
-- TABLET
-- ============================================================
Config.Tablet = {
    command = 'tablet',
    item = 'mechanic_tablet', -- nil para desativar necessidade de item
    requireJob = true,
    requireDuty = true,
}

-- ============================================================
-- LOGS
-- ============================================================
Config.Logging = {
    enabled = true,
    discord_webhook = '', -- webhook do Discord para logs (vazio = desativado)
}

-- ============================================================
-- ANTI-SPAM / COOLDOWNS
-- ============================================================
Config.Cooldowns = {
    repair = 5000, -- ms entre reparos
    diagnostic = 3000,
    billing = 10000,
    upgrade = 10000,
    partsShop = 1500,
}
