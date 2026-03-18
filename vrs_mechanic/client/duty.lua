-- ============================================================
-- VRS_MECHANIC - DUTY / STASH / LIFTS CLIENT
-- ============================================================

function VRS.ToggleDuty()
    if not VRS.IsMechanic() then
        lib.notify({ title = 'Erro', description = VRS.L.repair.not_mechanic, type = 'error' })
        return
    end

    TriggerServerEvent('QBCore:ToggleDuty')
    Wait(500)

    if VRS.IsOnDuty() then
        lib.notify({ title = 'Serviço', description = VRS.L.duty.on, type = 'success' })
    else
        lib.notify({ title = 'Serviço', description = VRS.L.duty.off, type = 'inform' })
    end
end

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

local function moveLift(shopId, liftIndex, direction)
    local ok, state = VRS.SetLiftHeight(
        shopId,
        liftIndex,
        ((VRS.LiftState and VRS.LiftState[VRS.GetLiftKey(shopId, liftIndex)] and VRS.LiftState[VRS.GetLiftKey(shopId, liftIndex)].height) or (Config.Lift.MinHeight or 0.0))
            + ((direction == 'up') and (Config.Lift.StepHeight or 0.15) or -(Config.Lift.StepHeight or 0.15)),
        true
    )

    if ok and state then
        lib.notify({
            title = 'Elevador',
            description = ('Elevador ajustado para %s.'):format(VRS.GetLiftHeightLabel(state.height or 0.0)),
            type = 'success',
        })
    end
end

function VRS.OpenLiftMenu(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    if not shop then return end

    if shop.type == 'owned' then
        if not VRS.IsMechanic() and shop.job then
            lib.notify({ title = 'Erro', description = VRS.L.notify.no_permission, type = 'error' })
            return
        end
        if Config.ShopRepair.requireDuty and not VRS.IsOnDuty() then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
            return
        end
    end

    local liftKey = VRS.GetLiftKey(shopId, liftIndex)
    local state = VRS.RefreshLiftState(shopId, liftIndex) or (VRS.LiftState and VRS.LiftState[liftKey]) or { height = Config.Lift.MinHeight or 0.0 }
    local vehicleNetId = state.vehicleNetId
    local vehicle = vehicleNetId and NetworkGetEntityFromNetworkId(vehicleNetId) or 0

    local options = {
        {
            title = 'Status do Elevador',
            description = ('Altura atual: %.2fm | %s'):format(state.height or 0.0, VRS.GetLiftHeightLabel(state.height or 0.0)),
            icon = 'fas fa-arrows-up-down',
            readOnly = true,
        },
    }

    if vehicleNetId and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = VRS.GetPlate(vehicle) or state.plate or '---'
        options[#options + 1] = {
            title = 'Diagnosticar veículo no elevador',
            description = ('Placa: %s'):format(plate),
            icon = 'fas fa-stethoscope',
            onSelect = function()
                VRS.FullDiagnostic(vehicle, shopId)
            end,
        }

        options[#options + 1] = {
            title = 'Iniciar serviço no elevador',
            description = 'Abrir painel de reparos e serviços completos.',
            icon = 'fas fa-tools',
            onSelect = function()
                VRS.OpenShopRepairMenu(vehicle, shopId)
            end,
        }

        if shop.services and shop.services.upgrades then
            options[#options + 1] = {
                title = VRS.L.shop.upgrades,
                description = VRS.L.shop.upgrades_desc,
                icon = 'fas fa-bolt',
                onSelect = function()
                    VRS.OpenUpgradeMenu(vehicle, shopId)
                end,
            }
        end

        if shop.services and shop.services.tyre_change then
            options[#options + 1] = {
                title = VRS.L.shop.tyre_change,
                description = VRS.L.shop.tyre_change_desc,
                icon = 'fas fa-circle',
                onSelect = function()
                    VRS.OpenTyreMenu(vehicle, shopId)
                end,
            }
        end

        options[#options + 1] = {
            title = 'Subir elevador',
            description = 'Elevar o veículo por um passo configurável.',
            icon = 'fas fa-arrow-up',
            onSelect = function()
                moveLift(shopId, liftIndex, 'up')
            end,
        }

        options[#options + 1] = {
            title = 'Descer elevador',
            description = 'Baixar o veículo por um passo configurável.',
            icon = 'fas fa-arrow-down',
            onSelect = function()
                moveLift(shopId, liftIndex, 'down')
            end,
        }

        options[#options + 1] = {
            title = 'Modo manual com setas',
            description = 'Use seta para cima/baixo para ajuste fino e ESC para sair.',
            icon = 'fas fa-keyboard',
            onSelect = function()
                VRS.StartManualLiftControl(shopId, liftIndex)
            end,
        }

        options[#options + 1] = {
            title = 'Altura de serviço do motor',
            description = ('Ajustar para %.2fm.'):format((Config.Lift.DefaultWorkHeights and Config.Lift.DefaultWorkHeights.engine) or 0.45),
            icon = 'fas fa-engine',
            onSelect = function()
                VRS.SetLiftPreset(shopId, liftIndex, 'engine')
            end,
        }

        options[#options + 1] = {
            title = 'Altura de serviço inferior',
            description = ('Ajustar para %.2fm.'):format((Config.Lift.DefaultWorkHeights and Config.Lift.DefaultWorkHeights.underbody) or 1.15),
            icon = 'fas fa-car-burst',
            onSelect = function()
                VRS.SetLiftPreset(shopId, liftIndex, 'underbody')
            end,
        }

        options[#options + 1] = {
            title = 'Retornar à posição inicial',
            description = 'Baixar totalmente o elevador até a base.',
            icon = 'fas fa-rotate-left',
            onSelect = function()
                VRS.SetLiftPreset(shopId, liftIndex, 'reset')
            end,
        }

        options[#options + 1] = {
            title = VRS.L.shop.lift_remove,
            description = (state.height or 0.0) > ((Config.Lift.MinHeight or 0.0) + 0.01) and 'Abaixe totalmente o elevador antes de retirar o veículo.' or 'Liberar o veículo da plataforma.',
            icon = 'fas fa-right-from-bracket',
            disabled = (state.height or 0.0) > ((Config.Lift.MinHeight or 0.0) + 0.01),
            onSelect = function()
                VRS.RemoveFromLift(shopId, liftIndex, vehicle)
            end,
        }
    else
        options[#options + 1] = {
            title = VRS.L.shop.lift_place,
            description = 'Posicionar o veículo mais próximo na plataforma.',
            icon = 'fas fa-car-side',
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

function VRS.PlaceOnLift(shopId, liftIndex)
    local vehicle = VRS.GetClosestVehicle(Config.Lift.snapDistance)
    if not vehicle then
        lib.notify({ title = 'Erro', description = VRS.L.shop.no_vehicle_near, type = 'error' })
        return
    end

    local shop = Config.Shops[shopId]
    local lift = shop and shop.lifts and shop.lifts[liftIndex]
    if not lift then return end

    local plate = VRS.GetPlate(vehicle)
    local coords, heading = VRS.GetLiftWorldCoords(shopId, liftIndex, Config.Lift.MinHeight or 0.0)
    if not coords then return end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver and driver ~= 0 then
        TaskLeaveVehicle(driver, vehicle, 0)
        Wait(1500)
    end

    SetEntityCoords(vehicle, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(vehicle, heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = lib.callback.await('vrs_mechanic:server:placeVehicleOnLift', false, shopId, liftIndex, netId, plate)
    if not result or not result.success then
        FreezeEntityPosition(vehicle, false)
        local reason = result and result.reason or 'unknown'
        local messages = {
            lift_occupied = VRS.L.shop.lift_occupied,
            no_access = VRS.L.notify.no_permission,
            not_on_duty = VRS.L.repair.not_on_duty,
            too_far = 'O veículo saiu da área válida do elevador.',
        }
        lib.notify({ title = 'Elevador', description = messages[reason] or 'Não foi possível posicionar o veículo.', type = 'error' })
        return
    end

    VRS.ApplyLiftState(shopId, liftIndex, result.state)
    lib.notify({ title = 'Elevador', description = 'Veículo posicionado e pronto para serviço.', type = 'success' })
    Wait(150)
    VRS.OpenLiftMenu(shopId, liftIndex)
end

function VRS.RemoveFromLift(shopId, liftIndex, vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = 'Veículo não encontrado.', type = 'error' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:removeVehicleFromLift', false, shopId, liftIndex)
    if not result or not result.success then
        local reason = result and result.reason or 'unknown'
        local messages = {
            lift_empty = VRS.L.shop.lift_empty,
            lift_not_lowered = 'Abaixe totalmente o elevador antes de retirar o veículo.',
            no_access = VRS.L.notify.no_permission,
            not_on_duty = VRS.L.repair.not_on_duty,
        }
        lib.notify({ title = 'Elevador', description = messages[reason] or 'Não foi possível retirar o veículo.', type = 'error' })
        return
    end

    FreezeEntityPosition(vehicle, false)

    local lift = Config.Shops[shopId].lifts[liftIndex]
    local exitOffset = Config.Lift.exitOffset or vec3(3.0, 0.0, 0.0)
    local exitCoords = GetOffsetFromEntityInWorldCoords(vehicle, exitOffset.x, exitOffset.y, exitOffset.z)
    SetEntityCoords(vehicle, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
    SetEntityHeading(vehicle, lift.coords.w or GetEntityHeading(vehicle))

    local liftKey = VRS.GetLiftKey(shopId, liftIndex)
    if VRS.LiftState then
        VRS.LiftState[liftKey] = { height = Config.Lift.MinHeight or 0.0, vehicleNetId = nil }
    end
    VRS.OnLift[liftKey] = nil

    local plate = VRS.GetPlate(vehicle)
    if plate then
        TriggerServerEvent('vrs_mechanic:server:saveVehicleStatus', plate)
    end

    lib.notify({ title = 'Elevador', description = 'Veículo retirado da plataforma com sucesso.', type = 'success' })
end

function VRS.OpenTyreMenu(vehicle, shopId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local options = {}
    local tyreNames = {
        [0] = 'Dianteiro esquerdo',
        [1] = 'Dianteiro direito',
        [2] = 'Traseiro esquerdo',
        [3] = 'Traseiro direito',
    }

    for i = 0, 3 do
        local burst = IsVehicleTyreBurst(vehicle, i, false)
        options[#options + 1] = {
            title = tyreNames[i],
            description = burst and 'Furado - clique para substituir.' or 'Sem necessidade de troca.',
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
    local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, 'tyre', false)
    if not hasMats then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        return
    end

    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'repair', 'tyre', { tyreIndex = tyreIndex })
    if not serviceState then return end

    VRS.PlayAnimation(serviceState.context.animationSet or 'repair_wheel')

    local success = lib.progressBar({
        duration = serviceState.context.duration or 8000,
        label = 'Trocando pneu...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)

    if not success then
        lib.notify({ title = 'Cancelado', description = VRS.L.repair.failed, type = 'error' })
        return
    end

    local removed = lib.callback.await('vrs_mechanic:server:removeItem', false, 'spare_tyre', 1)
    if not removed then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        return
    end

    SetVehicleTyreBurst(vehicle, tyreIndex, false, 1000.0)
    SetVehicleTyreFixed(vehicle, tyreIndex)

    lib.notify({ title = 'Pneu', description = 'Pneu trocado com sucesso!', type = 'success' })
end
