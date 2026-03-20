local VehicleKeys = {
    playerKeys = {},
    playerTempKeys = {
        plates = {},
        netIds = {},
        meta = {}
    },
    pendingSpawnClaims = {},
    AlertSend = false,
    isInDrivingSeat = false,
    currentVehicle = 0,
    showTextUi = false,
    hasKey = false,
    currentVehiclePlate = false,
    currentWeapon = false,
    isEngineRunning = false,
}

return VehicleKeys
