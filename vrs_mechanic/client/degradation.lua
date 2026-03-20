-- ============================================================
-- VRS_MECHANIC - DEGRADATION CLIENT
-- ============================================================

local lastPosition = nil
local totalDistance = 0.0
local lastCollisionCheck = 0
local lastDegradationUpdate = 0
local oilWarningShown = false
local lastEngineHealth = 1000.0
local lastBodyHealth = 1000.0

local function getTrackedVehicleContext()
    local vehicle = cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        return nil, nil, nil, nil
    end

    local plate = VRS.GetPlate(vehicle)
    local status = plate and VRS.VehicleStatus[plate] or nil
    local vehClass = GetVehicleClass(vehicle)

    return vehicle, plate, status, vehClass
end

local function processDistanceDegradation()
    local vehicle, plate, status, vehClass = getTrackedVehicleContext()
    if not vehicle then
        lastPosition = nil
        totalDistance = 0.0
        return
    end

    if not plate or Config.IgnoredVehicleClasses[vehClass] then
        lastPosition = GetEntityCoords(vehicle)
        totalDistance = 0.0
        return
    end

    local currentPos = GetEntityCoords(vehicle)
    if lastPosition then
        local dist = #(currentPos - lastPosition)
        local km = dist / 1000.0

        if km > 0.001 and km < 1.0 then
            totalDistance = totalDistance + km
            local now = GetGameTimer()
            if now - lastDegradationUpdate >= Config.Degradation.updateInterval then
                lastDegradationUpdate = now

                if totalDistance > 0.01 and status then
                    local updates = {}

                    for part, rate in pairs(Config.Degradation.distanceWear) do
                        if status[part] then
                            local damage = totalDistance * rate
                            local newVal = status[part] - damage
                            if newVal < 0 then newVal = 0 end
                            if math.abs(status[part] - newVal) > 0.1 then
                                updates[part] = newVal
                            end
                        end
                    end

                    if next(updates) then
                        TriggerServerEvent('vrs_mechanic:server:updateMultipleParts', plate, updates, NetworkGetNetworkIdFromEntity(vehicle))
                    end

                    totalDistance = 0.0
                end
            end
        end
    end

    lastPosition = currentPos
end

local function processCollisionDegradation()
    local vehicle, plate, status = getTrackedVehicleContext()
    if not vehicle then
        lastEngineHealth = 1000.0
        lastBodyHealth = 1000.0
        return
    end

    if plate and status then
        local currentEngine = GetVehicleEngineHealth(vehicle)
        local currentBody = GetVehicleBodyHealth(vehicle)
        local engineDrop = lastEngineHealth - currentEngine
        local bodyDrop = lastBodyHealth - currentBody

        if engineDrop > 20 or bodyDrop > 20 then
            local now = GetGameTimer()
            if now - lastCollisionCheck > 2000 then
                lastCollisionCheck = now

                local impactForce = math.max(engineDrop, bodyDrop) / 1000.0
                local updates = {}

                for part, mult in pairs(Config.Degradation.collisionDamage) do
                    if status[part] then
                        local max = Config.MaxStatus[part] or 100
                        local damage = impactForce * mult * max
                        local newVal = status[part] - damage
                        if newVal < 0 then newVal = 0 end
                        updates[part] = newVal
                    end
                end

                if next(updates) then
                    TriggerServerEvent('vrs_mechanic:server:updateMultipleParts', plate, updates, NetworkGetNetworkIdFromEntity(vehicle))
                end
            end
        end

        lastEngineHealth = currentEngine
        lastBodyHealth = currentBody
    end
end

local function processOilSystem()
    local vehicle, plate, status = getTrackedVehicleContext()
    if not vehicle or not plate or not status then return end

    local oilLevel = status.oil or Config.MaxStatus.oil
    local oilPct = VRS.GetPartPercent('oil', oilLevel)

    if oilPct <= Config.OilSystem.warningThreshold and not oilWarningShown then
        lib.notify({
            title = 'Atenção',
            description = VRS.L.notify.oil_low,
            type = 'warning',
        })
        oilWarningShown = true
    elseif oilPct > Config.OilSystem.warningThreshold then
        oilWarningShown = false
    end

    if oilPct <= Config.OilSystem.criticalThreshold then
        lib.notify({
            title = 'PERIGO',
            description = VRS.L.notify.oil_critical,
            type = 'error',
        })

        local engineDamage = Config.OilSystem.engineDamageRate
        local newEngine = (status.engine or Config.MaxStatus.engine) - engineDamage
        if newEngine < 0 then newEngine = 0 end
        TriggerServerEvent('vrs_mechanic:server:updatePart', plate, 'engine', newEngine, NetworkGetNetworkIdFromEntity(vehicle))
    end

    local radiatorPct = VRS.GetPartPercent('radiator', status.radiator or 0)
    if radiatorPct < Config.Degradation.radiatorOverheatThreshold then
        lib.notify({
            title = 'Atenção',
            description = VRS.L.notify.engine_overheat,
            type = 'error',
        })

        local engineDamage = Config.Degradation.radiatorEngineDamageRate
        local newEngine = (status.engine or Config.MaxStatus.engine) - engineDamage
        if newEngine < 0 then newEngine = 0 end
        TriggerServerEvent('vrs_mechanic:server:updatePart', plate, 'engine', newEngine, NetworkGetNetworkIdFromEntity(vehicle))
    end
end

local function processBatteryEffect()
    local vehicle, plate, status = getTrackedVehicleContext()
    if not vehicle or not plate or not status then return end

    local batteryPct = VRS.GetPartPercent('battery', status.battery or 0)
    if batteryPct < 20 and not GetIsVehicleEngineRunning(vehicle) then
        local failChance = Config.Degradation.batteryIgnitionFailChance
        if math.random(100) <= failChance then
            lib.notify({
                title = 'Veículo',
                description = VRS.L.notify.battery_fail,
                type = 'warning',
            })
            SetVehicleEngineOn(vehicle, false, true, true)
            Wait(3000)
        end
    end
end

-- ============================================================
-- DEGRADAÇÃO POR DISTÂNCIA
-- ============================================================

if not VRS.IsExperimentalEnabled('ClientLoopOptimization') then
    CreateThread(function()
        if not Config.Degradation.enabled then return end
        while true do
            processDistanceDegradation()
            Wait(2000)
        end
    end)

    CreateThread(function()
        if not Config.Degradation.enabled then return end
        while true do
            processCollisionDegradation()
            Wait(500)
        end
    end)

    CreateThread(function()
        if not Config.OilSystem.enabled then return end
        while true do
            processOilSystem()
            Wait(10000)
        end
    end)

    CreateThread(function()
        if not Config.Degradation.enabled then return end
        while true do
            processBatteryEffect()
            Wait(5000)
        end
    end)
else
    CreateThread(function()
        if not Config.Degradation.enabled and not Config.OilSystem.enabled then return end

        VRS.DebugLog('clientLoops', 'Scheduler otimizado de degradação ativado.')

        local timers = {
            distance = 0,
            collision = 0,
            oil = 0,
            battery = 0,
        }

        while true do
            local tickStartedAt = GetGameTimer()
            local now = tickStartedAt

            if Config.Degradation.enabled and now >= timers.distance then
                timers.distance = now + 2000
                processDistanceDegradation()
            end

            if Config.Degradation.enabled and now >= timers.collision then
                timers.collision = now + 500
                processCollisionDegradation()
            end

            if Config.OilSystem.enabled and now >= timers.oil then
                timers.oil = now + 10000
                processOilSystem()
            end

            if Config.Degradation.enabled and now >= timers.battery then
                timers.battery = now + 5000
                processBatteryEffect()
            end

            VRS.DebugMeasure('clientLoops', 'client.degradation.scheduler', tickStartedAt)
            Wait(cache.vehicle and 250 or 1000)
        end
    end)
end
