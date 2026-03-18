-- ============================================================
-- VRS_MECHANIC - CONTROLE AVANÇADO DE ELEVADOR
-- ============================================================

local manualLiftControl = {
    active = false,
    shopId = nil,
    liftIndex = nil,
}

local function getLiftKey(shopId, liftIndex)
    return ('%s_%s'):format(shopId, liftIndex)
end

local function roundHeight(value)
    return tonumber(('%0.2f'):format(value or 0.0)) or 0.0
end

function VRS.GetLiftKey(shopId, liftIndex)
    return getLiftKey(shopId, liftIndex)
end

function VRS.GetLiftBaseCoords(shopId, liftIndex)
    local shop = Config.Shops[shopId]
    local lift = shop and shop.lifts and shop.lifts[liftIndex]
    if not lift then return nil end

    return vec3(lift.coords.x, lift.coords.y, lift.coords.z), lift.coords.w or 0.0
end

function VRS.GetLiftHeightLabel(height)
    height = roundHeight(height)
    local presets = Config.Lift.DefaultWorkHeights or {}

    if math.abs(height - (Config.Lift.MinHeight or 0.0)) <= 0.05 then
        return 'Base'
    end
    if presets.engine and math.abs(height - presets.engine) <= 0.08 then
        return 'Serviço do motor'
    end
    if presets.wheel and math.abs(height - presets.wheel) <= 0.08 then
        return 'Serviço de roda/freio'
    end
    if presets.underbody and math.abs(height - presets.underbody) <= 0.08 then
        return 'Serviço inferior'
    end

    return ('%.2fm'):format(height)
end

function VRS.GetLiftWorldCoords(shopId, liftIndex, height)
    local baseCoords, heading = VRS.GetLiftBaseCoords(shopId, liftIndex)
    if not baseCoords then return nil end

    return vec3(baseCoords.x, baseCoords.y, baseCoords.z + roundHeight(height)), heading
end

function VRS.ApplyLiftState(shopId, liftIndex, state)
    if not state then return end

    local liftKey = getLiftKey(shopId, liftIndex)
    VRS.LiftState = VRS.LiftState or {}
    VRS.LiftState[liftKey] = state
    VRS.OnLift[liftKey] = state.vehicleNetId

    if not state.vehicleNetId then return end

    local vehicle = NetworkGetEntityFromNetworkId(state.vehicleNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local coords, heading = VRS.GetLiftWorldCoords(shopId, liftIndex, state.height or 0.0)
    if not coords then return end

    SetEntityCoords(vehicle, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(vehicle, heading)
    FreezeEntityPosition(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)
end

RegisterNetEvent('vrs_mechanic:client:syncLiftState', function(shopId, liftIndex, state)
    VRS.ApplyLiftState(shopId, liftIndex, state)
end)

function VRS.RefreshLiftState(shopId, liftIndex)
    local state = lib.callback.await('vrs_mechanic:server:getLiftState', false, shopId, liftIndex)
    if state then
        VRS.ApplyLiftState(shopId, liftIndex, state)
    end
    return state
end

function VRS.SetLiftHeight(shopId, liftIndex, targetHeight, reopenMenu)
    local result = lib.callback.await('vrs_mechanic:server:setLiftHeight', false, shopId, liftIndex, targetHeight)
    if result and result.success then
        VRS.ApplyLiftState(shopId, liftIndex, result.state)
        if reopenMenu then
            Wait(150)
            VRS.OpenLiftMenu(shopId, liftIndex)
        end
        return true, result.state
    end

    local reason = result and result.reason or 'unknown'
    local messages = {
        lift_empty = 'Não há veículo no elevador para mover.',
        already_top = 'O elevador já está na altura máxima.',
        already_bottom = 'O elevador já está totalmente abaixado.',
        no_access = VRS.L.notify.no_permission,
        not_on_duty = VRS.L.repair.not_on_duty,
        invalid_height = 'Altura inválida para este elevador.',
    }
    lib.notify({ title = 'Elevador', description = messages[reason] or 'Não foi possível ajustar a altura do elevador.', type = 'error' })
    return false
end

local function adjustLiftByStep(shopId, liftIndex, direction, reopenMenu)
    local liftKey = getLiftKey(shopId, liftIndex)
    local state = (VRS.LiftState and VRS.LiftState[liftKey]) or VRS.RefreshLiftState(shopId, liftIndex) or {}
    local currentHeight = state.height or Config.Lift.MinHeight or 0.0
    local step = Config.Lift.StepHeight or 0.15
    local targetHeight = currentHeight + (direction == 'up' and step or -step)
    return VRS.SetLiftHeight(shopId, liftIndex, targetHeight, reopenMenu)
end

function VRS.SetLiftPreset(shopId, liftIndex, presetName)
    local presets = Config.Lift.DefaultWorkHeights or {}
    local targetHeight = presets[presetName]
    if targetHeight == nil then
        lib.notify({ title = 'Elevador', description = 'Preset de altura inválido.', type = 'error' })
        return
    end

    local ok, state = VRS.SetLiftHeight(shopId, liftIndex, targetHeight, true)
    if ok and state then
        lib.notify({
            title = 'Elevador',
            description = ('Elevador ajustado para %s (%.2fm).'):format(VRS.GetLiftHeightLabel(state.height or 0.0), state.height or 0.0),
            type = 'success',
        })
    end
end

local function stopManualLiftControl()
    if not manualLiftControl.active then return end
    manualLiftControl.active = false
    manualLiftControl.shopId = nil
    manualLiftControl.liftIndex = nil
    lib.hideTextUI()
end

function VRS.StartManualLiftControl(shopId, liftIndex)
    if not Config.Lift.AllowManualArrowControl then
        lib.notify({ title = 'Elevador', description = 'O modo manual do elevador está desativado.', type = 'error' })
        return
    end

    local state = VRS.RefreshLiftState(shopId, liftIndex)
    if not state or not state.vehicleNetId then
        lib.notify({ title = 'Elevador', description = 'Posicione um veículo no elevador antes de usar o modo manual.', type = 'error' })
        return
    end

    stopManualLiftControl()
    manualLiftControl.active = true
    manualLiftControl.shopId = shopId
    manualLiftControl.liftIndex = liftIndex

    lib.showTextUI('Seta para cima: subir | Seta para baixo: descer | ESC / BACKSPACE: sair do ajuste', {
        position = 'top-center',
        icon = 'arrows-up-down',
    })
end

CreateThread(function()
    while true do
        if manualLiftControl.active then
            Wait(0)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)

            if IsControlJustPressed(0, 172) then
                adjustLiftByStep(manualLiftControl.shopId, manualLiftControl.liftIndex, 'up', false)
            elseif IsControlJustPressed(0, 173) then
                adjustLiftByStep(manualLiftControl.shopId, manualLiftControl.liftIndex, 'down', false)
            elseif IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                local shopId = manualLiftControl.shopId
                local liftIndex = manualLiftControl.liftIndex
                stopManualLiftControl()
                Wait(100)
                VRS.OpenLiftMenu(shopId, liftIndex)
            end
        else
            Wait(300)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopManualLiftControl()
end)
