-- ============================================================
-- VRS_MECHANIC - DUTY / STASH / LIFTS CLIENT
-- ============================================================

local function requestControl(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function removeVehicleOccupants(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = -1, maxPassengers - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 then
            TaskLeaveVehicle(ped, vehicle, 0)
        end
    end
end

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

function VRS.OpenLiftMenu(shopId, liftIndex)
    local resolvedLift, resolveReason = VRS.ResolveLiftReference(shopId, liftIndex)
    if not resolvedLift then
        VRS.LiftDebugLog('liftMenu', ('Falha ao resolver elevador para abrir menu. shop=%s lift=%s reason=%s'):format(tostring(shopId), tostring(liftIndex), tostring(resolveReason)))
        lib.notify({ title = 'Elevador', description = 'Não foi possível localizar este elevador.', type = 'error' })
        return
    end

    shopId = resolvedLift.shopId
    liftIndex = resolvedLift.liftIndex

    local shop = resolvedLift.shop
    local lift = resolvedLift.lift

    if shop.type == 'owned' then
        if not VRS.IsMechanic() and shop.job then
            lib.notify({ title = 'Erro', description = VRS.L.notify.no_permission, type = 'error' })
            return
        end
        if Config.Lift.requireDuty and not VRS.IsOnDuty() then
            lib.notify({ title = 'Erro', description = VRS.L.repair.not_on_duty, type = 'error' })
            return
        end
    end

    local liftKey = resolvedLift.liftKey
    if not liftKey then
        VRS.LiftDebugLog('liftMenu', ('Chave do elevador indisponível. shop=%s lift=%s'):format(tostring(shopId), tostring(liftIndex)))
        lib.notify({ title = 'Elevador', description = 'Falha ao resolver a chave do elevador.', type = 'error' })
        return
    end

    VRS.LiftDebugLog('liftMenu', ('Abrindo menu do elevador %s para shop=%s index=%s'):format(liftKey, shopId, liftIndex))
    local state = VRS.GetLiftStateSnapshot(shopId, liftIndex)
    if VRS.RefreshLiftState then
        state = VRS.RefreshLiftState(shopId, liftIndex) or state
    end
    local vehicleNetId = state.vehicleNetId
    local vehicle = vehicleNetId and VRS.GetEntityFromNetId(vehicleNetId, true) or 0

    local liftName = VRS.GetLiftDisplayName(lift, liftIndex)
    local menuId = ('vrs_lift_menu_%s'):format(lift.id or liftKey)

    local options = {
        {
            title = liftName,
            description = ('ID: %s | Altura atual: %.2fm | %s'):format(lift.id or liftKey, state.height or 0.0, VRS.GetLiftHeightLabel(state.height or 0.0, shopId, liftIndex)),
            icon = 'fas fa-arrows-up-down',
            readOnly = true,
        },
    }

    if vehicleNetId and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local plate = VRS.GetPlate(vehicle) or state.plate or '---'
        options[#options + 1] = {
            title = 'Veículo vinculado',
            description = ('Placa: %s | Elevador isolado: %s'):format(plate, liftName),
            icon = 'fas fa-car-side',
            readOnly = true,
        }

        options[#options + 1] = {
            title = 'Diagnóstico rápido',
            description = 'Executar diagnóstico do veículo atualmente vinculado a este elevador.',
            icon = 'fas fa-stethoscope',
            onSelect = function()
                VRS.FullDiagnostic(vehicle, shopId)
            end,
        }

        options[#options + 1] = {
            title = 'Painel do elevador',
            description = 'Subir, descer, parar e acessar posições rápidas deste elevador.',
            icon = 'fas fa-sliders',
            onSelect = function()
                VRS.OpenLiftPanel(shopId, liftIndex)
            end,
        }

        options[#options + 1] = {
            title = 'Reparos e manutenção',
            description = 'Abrir serviços de oficina organizados por categoria para este veículo.',
            icon = 'fas fa-tools',
            onSelect = function()
                VRS.OpenShopRepairMenu(vehicle, shopId, {
                    parentMenu = menuId,
                    liftId = lift.id,
                    liftName = liftName,
                })
            end,
        }

        if shop.services and shop.services.upgrades then
            options[#options + 1] = {
                title = 'Upgrades por categoria',
                description = 'Abrir instalação de upgrades somente para o veículo deste elevador.',
                icon = 'fas fa-bolt',
                onSelect = function()
                    VRS.OpenUpgradeMenu(vehicle, shopId, {
                        parentMenu = menuId,
                        liftId = lift.id,
                        liftName = liftName,
                    })
                end,
            }
        end

        if shop.services and shop.services.tyre_change then
            options[#options + 1] = {
                title = 'Pneus e rodas',
                description = 'Troca guiada para rodas do veículo atualmente preso neste elevador.',
                icon = 'fas fa-circle',
                onSelect = function()
                    VRS.OpenTyreMenu(vehicle, shopId, {
                        parentMenu = menuId,
                        liftId = lift.id,
                        liftName = liftName,
                    })
                end,
            }
        }

        options[#options + 1] = {
            title = VRS.L.shop.lift_remove,
            description = (state.height or 0.0) > (((state.minHeight or Config.Lift.MinHeight or 0.0)) + 0.05)
                and 'Abaixe totalmente o elevador antes de retirar o veículo.'
                or 'Liberar o veículo da plataforma.',
            icon = 'fas fa-right-from-bracket',
            disabled = (state.height or 0.0) > (((state.minHeight or Config.Lift.MinHeight or 0.0)) + 0.05),
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
        id = menuId,
        title = ('%s - %s'):format(shop.label, liftName),
        options = options,
    })

    lib.showContext(menuId)
end

function VRS.PlaceOnLift(shopId, liftIndex)
    local vehicle, reason, placement = VRS.FindBestVehicleForLift(shopId, liftIndex, Config.Lift.snapDistance)
    if not vehicle then
        local messages = {
            no_vehicle = VRS.L.shop.no_vehicle_near,
            invalid_vehicle = 'Nenhum veículo válido foi encontrado próximo ao elevador.',
            vehicle_moving = 'O veículo precisa estar completamente parado para usar o elevador.',
            vehicle_occupied = 'Retire todos os ocupantes do veículo antes de usar o elevador.',
            vehicle_bad_heading = 'Alinhe melhor o veículo com o elevador antes de posicioná-lo.',
            vehicle_outside_length = 'Aproxime mais o veículo do centro do elevador.',
            vehicle_outside_width = 'Centralize melhor o veículo entre as colunas do elevador.',
            vehicle_already_on_other_lift = 'Este veículo já está vinculado a outro elevador.',
            unsupported_vehicle = 'Este tipo de veículo não é compatível com este elevador.',
        }
        lib.notify({ title = 'Elevador', description = messages[reason] or VRS.L.shop.no_vehicle_near, type = 'error' })
        return
    end

    local resolvedLift = VRS.ResolveLiftReference(shopId, liftIndex)
    local lift = resolvedLift and resolvedLift.lift or nil
    if not lift then return end

    local plate = VRS.GetPlate(vehicle)
    local coords, heading = VRS.GetLiftWorldCoords(shopId, liftIndex, (lift.minHeight or Config.Lift.MinHeight or 0.0))
    if not coords then return end

    removeVehicleOccupants(vehicle)
    Wait(1000)

    -- Posicionar veículo na plataforma
    requestControl(vehicle)
    SetEntityCoords(vehicle, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(vehicle, heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)

    -- Desabilitar colisão com plataforma
    local liftData = VRS.GetLiftPropData(shopId, liftIndex)
    if liftData and liftData.platform and DoesEntityExist(liftData.platform) then
        SetEntityNoCollisionEntity(liftData.platform, vehicle, true)
        SetEntityNoCollisionEntity(vehicle, liftData.platform, true)
    end

    local netId, netReason = VRS.GetSafeNetId(vehicle)
    if not netId then
        FreezeEntityPosition(vehicle, false)
        lib.notify({ title = 'Elevador', description = ('Falha de rede ao registrar o veículo (%s).'):format(netReason or 'sem net id'), type = 'error' })
        return
    end

    local aligned, alignedReason = VRS.ValidateVehicleForLift(shopId, liftIndex, vehicle)
    if not aligned then
        FreezeEntityPosition(vehicle, false)
        local messages = {
            vehicle_bad_heading = 'O veículo não ficou alinhado corretamente sobre o elevador.',
            vehicle_outside_length = 'O veículo ficou fora do comprimento útil do elevador.',
            vehicle_outside_width = 'O veículo ficou fora da largura útil do elevador.',
            vehicle_occupied = 'Ainda existe ocupante no veículo.',
        }
        lib.notify({ title = 'Elevador', description = messages[alignedReason] or 'Não foi possível alinhar o veículo no elevador.', type = 'error' })
        return
    end

    local result = lib.callback.await('vrs_mechanic:server:placeVehicleOnLift', false, shopId, liftIndex, netId, plate)
    if not result or not result.success then
        FreezeEntityPosition(vehicle, false)
        local reason = result and result.reason or 'unknown'
        local messages = {
            lift_occupied = VRS.L.shop.lift_occupied,
            no_access = VRS.L.notify.no_permission,
            not_on_duty = VRS.L.repair.not_on_duty,
            too_far = 'O veículo saiu da área válida do elevador.',
            lift_busy = 'Elevador em movimento. Aguarde.',
            invalid_vehicle = 'A entidade do veículo ficou inválida durante o posicionamento.',
            vehicle_already_on_other_lift = 'Este veículo já está associado a outro elevador.',
            vehicle_bad_heading = 'O servidor recusou o veículo por desalinhamento.',
            vehicle_outside_length = 'O servidor recusou o veículo por estar fora do comprimento útil.',
            vehicle_outside_width = 'O servidor recusou o veículo por estar fora da largura útil.',
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
            lift_busy = 'Elevador em movimento. Aguarde.',
        }
        lib.notify({ title = 'Elevador', description = messages[reason] or 'Não foi possível retirar o veículo.', type = 'error' })
        return
    end

    requestControl(vehicle)
    FreezeEntityPosition(vehicle, false)

    local liftKey = VRS.GetLiftKey(shopId, liftIndex)
    local resolvedLift = VRS.ResolveLiftReference(shopId, liftIndex)
    local minHeight = (resolvedLift and resolvedLift.lift and resolvedLift.lift.minHeight) or Config.Lift.MinHeight or 0.0
    if VRS.LiftState then
        VRS.LiftState[liftKey] = { height = minHeight, minHeight = minHeight, vehicleNetId = nil }
    end
    VRS.OnLift[liftKey] = nil

    local plate = VRS.GetPlate(vehicle)
    if plate then
        TriggerServerEvent('vrs_mechanic:server:saveVehicleStatus', plate)
    end

    lib.notify({ title = 'Elevador', description = 'Veículo retirado da plataforma com sucesso.', type = 'success' })
end

function VRS.OpenTyreMenu(vehicle, shopId, menuOptions)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    menuOptions = menuOptions or {}
    local plate = VRS.GetPlate(vehicle) or 'SEMPLACA'
    local menuId = ('vrs_tyre_menu_%s_%s'):format(menuOptions.liftId or shopId, plate)

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
        id = menuId,
        title = 'Troca de Pneus',
        menu = menuOptions.parentMenu or 'vrs_lift_menu',
        options = options,
    })

    lib.showContext(menuId)
end

function VRS.RepairTyre(vehicle, tyreIndex, shopId)
    local hasMats = lib.callback.await('vrs_mechanic:server:checkMaterials', false, 'tyre', false)
    if not hasMats then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_items, type = 'error' })
        return
    end

    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'repair', 'tyre', { tyreIndex = tyreIndex })
    if not serviceState then return end

    VRS.PlayServiceAnimation(vehicle, serviceState.context, 'repair_wheel')

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
