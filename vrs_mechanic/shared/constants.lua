-- ============================================================
-- CONSTANTES GLOBAIS DO VRS_MECHANIC
-- ============================================================

VRS = VRS or {}

-- Status de ordem de serviço
VRS.OrderStatus = {
    OPEN      = 'open',
    PROGRESS  = 'progress',
    WAITING   = 'waiting',
    DONE      = 'done',
    DELIVERED = 'delivered',
}

-- Partes reparáveis
VRS.Parts = {
    'engine', 'body', 'oil', 'radiator', 'brakes', 'clutch',
    'axle', 'battery', 'suspension', 'transmission', 'fuel_tank',
}

-- Partes que usam escala 0-1000 (GTA nativo)
VRS.HighScaleParts = {
    engine = true,
    body = true,
}

-- Upgrade types
VRS.UpgradeTypes = {
    'engine_v6', 'engine_v8', 'turbo', 'ecu_stage1', 'ecu_stage2',
    'nitrous', 'brakes_sport', 'suspension_sport',
}

-- Mapeamento de upgrade para mod index GTA
VRS.UpgradeModIndex = {
    engine_v6       = { modType = 11, modIndex = 1 },  -- Engine
    engine_v8       = { modType = 11, modIndex = 3 },
    turbo           = { modType = 18, modIndex = 0 },   -- Turbo
    ecu_stage1      = { modType = 11, modIndex = 2 },
    ecu_stage2      = { modType = 11, modIndex = 3 },
    nitrous         = nil, -- tratado separadamente
    brakes_sport    = { modType = 12, modIndex = 2 },   -- Brakes
    suspension_sport = { modType = 15, modIndex = 2 },   -- Suspension
}
