-- ============================================================
-- VRS_MECHANIC - DUTY CLIENT
-- ============================================================

--- Alternar duty
function VRS.ToggleDuty()
    if not VRS.IsMechanic() then
        lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
        return
    end

    TriggerServerEvent('QBCore:ToggleDuty')

    -- Aguardar atualização
    Wait(500)

    if VRS.IsOnDuty() then
        lib.notify({ title = 'Serviço', description = VRS.L.duty.on, type = 'success' })
    else
        lib.notify({ title = 'Serviço', description = VRS.L.duty.off, type = 'inform' })
    end
end

-- Abrir stash
function VRS.OpenStash(shopId)
    if not shopId then return end

    local shop = Config.Shops[shopId]
    if not shop or not shop.stash then return end

    if shop.type == 'owned' then
        if not VRS.IsMechanic() then
            lib.notify({ title = 'Erro', description = VRS.L.notify.no_permission, type = 'error' })
            return
        end
        if not VRS.IsOnDuty() then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
            return
        end
    end

    lib.callback.await('vrs_mechanic:server:openStash', false, shopId)
end

-- ============================================================
-- MENU DO ELEVADOR
-- ============================================================

--- Abre menu do elevador
---@param shopId string
---@param liftIndex number
function VRS.OpenLiftMenu(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    if not shop then return end

    -- Para oficina owned, verificar permissões
    if shop.type == 'owned' then
        if not VRS.IsMechanic() and shop.job then
            lib.notify({ title = 'Erro', description = VRS.L.notify.no_permission, type = 'error' })
            return
        end
    end

    local liftKey = ('%s_%d'):format(shopId, liftIndex)
    local vehicleOnLift = VRS.OnLift[liftKey]

    local options = {}

    if vehicleOnLift then
        -- Veículo no elevador: mostrar opções de serviço
        local vehicle = NetworkGetEntityFromNetworkId(vehicleOnLift)

        if vehicle and DoesEntityExist(vehicle) then
            local plate = VRS.GetPlate(vehicle)

            if shop.services then
                if shop.services.diagnostic then
                    options[#options + 1] = {
                        title = VRS.L.shop.diagnostic,
                        description = VRS.L.shop.diagnostic_desc,
                        icon = 'fas fa-stethoscope',
                        onSelect = function()
                            VRS.FullDiagnostic(vehicle, shopId)
                        end,
                    }
                end

                if shop.services.repair then
                    options[#options + 1] = {
                        title = VRS.L.shop.repair,
                        description = VRS.L.shop.repair_desc,
                        icon = 'fas fa-tools',
                        onSelect = function()
                            VRS.OpenShopRepairMenu(vehicle, shopId)
                        end,
                    }
                end

                if shop.services.upgrades then
                    options[#options + 1] = {
                        title = VRS.L.shop.upgrades,
                        description = VRS.L.shop.upgrades_desc,
                        icon = 'fas fa-bolt',
                        onSelect = function()
                            VRS.OpenUpgradeMenu(vehicle, shopId)
                        end,
                    }
                end

                if shop.services.tyre_change then
                    options[#options + 1] = {
                        title = VRS.L.shop.tyre_change,
                        description = VRS.L.shop.tyre_change_desc,
                        icon = 'fas fa-circle',
                        onSelect = function()
                            VRS.OpenTyreMenu(vehicle, shopId)
                        end,
                    }
                end
            end

            -- Retirar do elevador
            options[#options + 1] = {
                title = VRS.L.shop.lift_remove,
                icon = 'fas fa-arrow-down',
                onSelect = function()
                    VRS.RemoveFromLift(shopId, liftIndex, vehicle)
                end,
            }
        else
            -- Veículo não existe mais
            VRS.OnLift[liftKey] = nil
        end
    else
        -- Elevador vazio: colocar veículo
        options[#options + 1] = {
            title = VRS.L.shop.lift_place,
            description = 'Colocar veículo próximo no elevador',
            icon = 'fas fa-arrow-up',
            onSelect = function()
                VRS.PlaceOnLift(shopId, liftIndex)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_lift_menu',
        title = VRS.L.shop.title:format(shop.label),
        options = options,
    })

    lib.showContext('vrs_lift_menu')
end

--- Colocar veículo no elevador
---@param shopId string
---@param liftIndex number
function VRS.PlaceOnLift(shopId, liftIndex)
    local vehicle = VRS.GetClosestVehicle(Config.Lift.snapDistance)
    if not vehicle then
        lib.notify({ title = 'Erro', description = VRS.L.shop.no_vehicle_near, type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    local lift = shop.lifts[liftIndex]
    if not lift then return end

    -- Mover veículo para posição do elevador
    local liftCoords = vec3(lift.coords.x, lift.coords.y, lift.coords.z)
    local heading = lift.coords.w or 0.0

    -- Garantir que ninguém está no veículo
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver and driver ~= 0 then
        TaskLeaveVehicle(driver, vehicle, 0)
        Wait(2000)
    end

    SetEntityCoords(vehicle, liftCoords.x, liftCoords.y, liftCoords.z, false, false, false, false)
    SetEntityHeading(vehicle, heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)

    -- Registrar veículo no elevador
    local liftKey = ('%s_%d'):format(shopId, liftIndex)
    VRS.OnLift[liftKey] = NetworkGetNetworkIdFromEntity(vehicle)

    lib.notify({ title = 'Elevador', description = 'Veículo posicionado.', type = 'success' })

    -- Abrir menu automaticamente
    Wait(500)
    VRS.OpenLiftMenu(shopId, liftIndex)
end

--- Retirar veículo do elevador
---@param shopId string
---@param liftIndex number
---@param vehicle number
function VRS.RemoveFromLift(shopId, liftIndex, vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = 'Veículo não encontrado.', type = 'error' })
        return
    end

    FreezeEntityPosition(vehicle, false)

    -- Salvar status
    local plate = VRS.GetPlate(vehicle)
    if plate then
        TriggerServerEvent('vrs_mechanic:server:saveVehicleStatus', plate)
    end

    local liftKey = ('%s_%d'):format(shopId, liftIndex)
    VRS.OnLift[liftKey] = nil

    lib.notify({ title = 'Elevador', description = 'Veículo liberado.', type = 'success' })
end

-- ============================================================
-- MENU DE PNEUS
-- ============================================================

function VRS.OpenTyreMenu(vehicle, shopId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local options = {}
    local tyreNames = {
        [0] = 'Dianteiro Esquerdo',
        [1] = 'Dianteiro Direito',
        [2] = 'Traseiro Esquerdo',
        [3] = 'Traseiro Direito',
    }

    for i = 0, 3 do
        local burst = IsVehicleTyreBurst(vehicle, i, false)
        options[#options + 1] = {
            title = tyreNames[i],
            description = burst and 'FURADO - Clique para trocar' or 'OK',
            icon = burst and 'fas fa-times-circle' or 'fas fa-check-circle',
            iconColor = burst and '#F44336' or '#4CAF50',
            disabled = not burst,
            onSelect = function()
                VRS.RepairTyre(vehicle, i, shopId)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_tyre_menu',
        title = 'Troca de Pneus',
        menu = 'vrs_lift_menu',
        options = options,
    })

    lib.showContext('vrs_tyre_menu')
end

function VRS.RepairTyre(vehicle, tyreIndex, shopId)
    -- Verificar material
    local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, 'tyre', false)
    if not hasMats then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        return
    end

    VRS.PlayAnimation('repair_wheel')

    local success = lib.progressBar({
        duration = 8000,
        label = 'Trocando pneu...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.repair.failed, type = 'error' })
        return
    end

    -- Consumir item no server
    local removed = lib.callback.await('vrs_mechanic:server:removeItem', false, 'spare_tyre', 1)
    if not removed then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        return
    end

    -- Fixar pneu
    SetVehicleTyreBurst(vehicle, tyreIndex, false, 1000.0)
    SetVehicleTyreFixed(vehicle, tyreIndex)

    lib.notify({ title = 'Pneu', description = 'Pneu trocado com sucesso!', type = 'success' })
end
