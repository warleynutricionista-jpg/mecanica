-- ============================================================
-- VRS_MECHANIC - DEGRADATION CLIENT
-- ============================================================

local lastPosition = nil
local totalDistance = 0.0
local lastCollisionCheck = 0
local lastDegradationUpdate = 0
local oilWarningShown = false

-- ============================================================
-- DEGRADAÇÃO POR DISTÂNCIA
-- ============================================================

CreateThread(function()
    if not Config.Degradation.enabled then return end

    while true do
        local vehicle = cache.vehicle

        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)
            local vehClass = GetVehicleClass(vehicle)

            if plate and not Config.IgnoredVehicleClasses[vehClass] then
                local currentPos = GetEntityCoords(vehicle)

                if lastPosition then
                    local dist = #(currentPos - lastPosition)

                    -- Converter para km aproximado (escala GTA)
                    local km = dist / 1000.0

                    if km > 0.001 and km < 1.0 then -- evitar teletransporte
                        totalDistance = totalDistance + km

                        -- Aplicar degradação a cada intervalo configurado
                        local now = GetGameTimer()
                        if now - lastDegradationUpdate >= Config.Degradation.updateInterval then
                            lastDegradationUpdate = now

                            if totalDistance > 0.01 then
                                local status = VRS.VehicleStatus[plate]
                                if status then
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
                                        TriggerServerEvent('vrs_mechanic:server:updateMultipleParts', plate, updates)
                                    end

                                    totalDistance = 0.0
                                end
                            end
                        end
                    end
                end

                lastPosition = currentPos
            end
        else
            lastPosition = nil
            totalDistance = 0.0
        end

        Wait(2000)
    end
end)

-- ============================================================
-- DEGRADAÇÃO POR COLISÃO
-- ============================================================

CreateThread(function()
    if not Config.Degradation.enabled then return end

    local lastEngineHealth = 1000.0
    local lastBodyHealth = 1000.0

    while true do
        local vehicle = cache.vehicle

        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)

            if plate and VRS.VehicleStatus[plate] then
                local currentEngine = GetVehicleEngineHealth(vehicle)
                local currentBody = GetVehicleBodyHealth(vehicle)

                -- Detectar colisão por queda de health
                local engineDrop = lastEngineHealth - currentEngine
                local bodyDrop = lastBodyHealth - currentBody

                if engineDrop > 20 or bodyDrop > 20 then
                    local now = GetGameTimer()
                    if now - lastCollisionCheck > 2000 then -- debounce
                        lastCollisionCheck = now

                        local status = VRS.VehicleStatus[plate]
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
                            TriggerServerEvent('vrs_mechanic:server:updateMultipleParts', plate, updates)
                        end
                    end
                end

                lastEngineHealth = currentEngine
                lastBodyHealth = currentBody
            end
        else
            lastEngineHealth = 1000.0
            lastBodyHealth = 1000.0
        end

        Wait(500)
    end
end)

-- ============================================================
-- SISTEMA DE ÓLEO
-- ============================================================

CreateThread(function()
    if not Config.OilSystem.enabled then return end

    while true do
        local vehicle = cache.vehicle

        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)

            if plate and VRS.VehicleStatus[plate] then
                local status = VRS.VehicleStatus[plate]
                local oilLevel = status.oil or Config.MaxStatus.oil

                -- Avisos de óleo
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

                -- Óleo crítico: danifica motor
                if oilPct <= Config.OilSystem.criticalThreshold then
                    lib.notify({
                        title = 'PERIGO',
                        description = VRS.L.notify.oil_critical,
                        type = 'error',
                    })

                    -- Dano ao motor
                    local engineDamage = Config.OilSystem.engineDamageRate
                    local newEngine = (status.engine or Config.MaxStatus.engine) - engineDamage
                    if newEngine < 0 then newEngine = 0 end
                    TriggerServerEvent('vrs_mechanic:server:updatePart', plate, 'engine', newEngine)
                end

                -- Radiador ruim: superaquecimento
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
                    TriggerServerEvent('vrs_mechanic:server:updatePart', plate, 'engine', newEngine)
                end
            end
        end

        Wait(10000) -- Verificar a cada 10 segundos
    end
end)

-- ============================================================
-- EFEITO DE BATERIA FRACA
-- ============================================================

CreateThread(function()
    if not Config.Degradation.enabled then return end

    while true do
        local vehicle = cache.vehicle

        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)

            if plate and VRS.VehicleStatus[plate] then
                local status = VRS.VehicleStatus[plate]
                local batteryPct = VRS.GetPartPercent('battery', status.battery or 0)

                -- Bateria fraca: chance de falha na ignição
                if batteryPct < 20 then
                    if not GetIsVehicleEngineRunning(vehicle) then
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
            end
        end

        Wait(5000)
    end
end)
