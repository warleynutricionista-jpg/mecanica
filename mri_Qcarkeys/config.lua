Config = Config or {}

Config.Debug = false
Config.TempKeysEnabled = true
Config.TempKeyAutoExpire = true
Config.TempKeyExpireMinutes = 30
Config.GiveTempKeysToServiceVehicles = true
Config.GiveKeysToAdminSpawnedVehicles = true
Config.AdminSpawnFallback = true

Config.SearchKey = {
    Enabled = true,
    GloveboxChance = 0.30,
    TrunkChance = 0.25,
    NoKeyChance = 0.15,
    Duration = 7000,
    RequireOpenCompartments = true
}

Config.NPCSearch = {
    Enabled = true,
    Duration = 5000,
    MaxDistance = 4.0,
    KeyChance = 0.30
}

Config.Hotwire = {
    Enabled = true,
    RequiredItem = 'screwdriver',
    ConsumeItem = true,
    Duration = 9500,
    SuccessChance = 0.25,
    PermanentElectricalDamageChance = 0.45,
    BlockIfPermanentDamage = true,
    SevereDamageChance = 0.70,
    BlockEngineOnPermanentDamage = true
}

Config.Lockpick = {
    Enabled = true,
    Item = 'lockpick',
    AdvancedItem = 'advancedlockpick',
    Stages = 6,
    FailMode = 'fail', -- fail | regress
    BreakChance = 0.5,
    AdvancedBreakChance = 0.10,
    StageDuration = 1200,
    RegressAmount = 1
}

Config.Security = {
    ActionCooldownMs = 1200,
    MaxInteractDistance = 5.0
}

Config.Locale = {
    vehicleLocked = 'Veículo trancado',
    vehicleUnlocked = 'Veículo destrancado',
    actionCancelled = 'Ação cancelada!',
    keyFound = 'Você encontrou a chave do veículo!',
    keyNotFound = 'Você não encontrou a chave neste local.',
    emptyCompartment = 'Compartimento vazio.',
    compartmentClosed = 'Abra o compartimento antes de revistar.',
    alreadySearched = 'Esse compartimento já foi revistado.',
    npcNoKeys = 'O NPC não estava com a chave.',
    npcEscapedWithKeys = 'O NPC fugiu com a chave.',
    missingHotwireTool = 'Você precisa de uma chave de fenda.',
    hotwireToolConsumed = 'Você usou uma chave de fenda.',
    irreversibleElectricalDamage = 'O veículo sofreu dano elétrico irreversível.',
    mechanicRequired = 'A ignição precisa de reparo de mecânico.',
    lockpickProgress = 'Destravamento %s/%s',
    lockpickFailed = 'Você falhou no lockpick.',
    lockpickCancelled = 'Lockpick cancelado.',
    hotwireFailed = 'A ligação direta falhou.',
    hotwireSuccess = 'Ligação direta concluída.',
    tooFar = 'Você está longe demais da ação.',
    actionBlocked = 'Ação bloqueada por segurança.',
    invalidTarget = 'Alvo inválido.'
}
