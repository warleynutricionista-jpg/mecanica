Paintjob = Paintjob or {}
Paintjob.Paint = Paintjob.Paint or {}
Paintjob.State = Paintjob.State or {
    busyBooths = {},
    activeSession = nil,
    painter = nil,
}

local Utils = Paintjob.Utils
local Effects = Paintjob.Effects
local Paint = Paintjob.Paint
local State = Paintjob.State

local function cloneColor(value)
    return {
        r = value.r,
        g = value.g,
        b = value.b,
    }
end

local function destroySessionCamera()
    local painter = State.painter
    if not painter or not painter.camera then return end

    RenderScriptCams(false, true, Config.UI.Camera.easeTime or 500, true, false)
    DestroyCam(painter.camera, false)
    painter.camera = nil
end

local function setupSessionCamera(session)
    if not Config.UI.Camera.enabled then return end
    if not session or not Utils.isValidVehicle(session.vehicle) then return end

    local booth = Utils.getBooth(session.boothId)
    if not booth then return end

    destroySessionCamera()

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local pointAt = booth.previewCam and Utils.toVec3(booth.previewCam.pointAt) or GetOffsetFromEntityInWorldCoords(session.vehicle, 0.0, 0.0, 0.4)
    local camCoords = booth.previewCam and Utils.toVec3(booth.previewCam.coords) or GetOffsetFromEntityInWorldCoords(session.vehicle, -3.5, -5.2, 1.8)

    if not camCoords or not pointAt then
        DestroyCam(cam, false)
        return
    end

    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, pointAt.x, pointAt.y, pointAt.z)
    SetCamFov(cam, Config.UI.Camera.fov or 42.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, Config.UI.Camera.easeTime or 500, true, false)

    State.painter = State.painter or {}
    State.painter.camera = cam
end

local function releaseSession(reason, silent)
    local session = State.activeSession
    if not session then return end

    if lib.progressActive() then
        lib.cancelProgress()
    end

    Effects.stopBooth(session.boothId)
    destroySessionCamera()

    if Utils.isValidVehicle(session.vehicle) then
        FreezeEntityPosition(session.vehicle, false)
        Utils.applyPaintState(session.vehicle, session.originalState)
    end

    TriggerServerEvent('mri_Qpaintjob:server:releaseSession', session.boothId, session.token, reason or 'release')
    State.activeSession = nil
    State.painter = nil

    if not silent and reason and reason ~= 'completed' then
        Utils.notify({
            type = 'warning',
            description = 'Sessão encerrada: ' .. reason,
        })
    end
end

function Paint.applyPreview(session)
    if not session or not Utils.isValidVehicle(session.vehicle) then return end

    local previewState = {
        primary = session.selection.primary,
        secondary = session.selection.secondary,
        finish = session.selection.finish,
        secondaryFinish = session.selection.finish,
        primaryColorIndex = session.originalState.primaryColorIndex,
        secondaryColorIndex = session.originalState.secondaryColorIndex,
        pearlescentColor = session.originalState.pearlescentColor,
        wheelColor = session.originalState.wheelColor,
    }

    Utils.applyPaintState(session.vehicle, previewState)
end

function Paint.restoreOriginal(session)
    if not session or not Utils.isValidVehicle(session.vehicle) then return end
    Utils.applyPaintState(session.vehicle, session.originalState)
end

function Paint.beginSession(boothId)
    if State.activeSession then
        Utils.notify({ type = 'error', description = 'Já existe uma cabine em edição.' })
        return nil
    end

    local booth = Utils.getBooth(boothId)
    if not booth then
        Utils.notify({ type = 'error', description = 'Cabine inválida.' })
        return nil
    end

    local vehicle, reason = Utils.findVehicleInBooth(boothId)
    if not vehicle then
        local message = reason == 'vehicle_outside_booth' and 'Posicione o veículo corretamente dentro da cabine.' or 'Nenhum veículo foi detectado na cabine.'
        Utils.notify({ type = 'error', description = message })
        return nil
    end

    local netId = Utils.getSafeNetId(vehicle)
    if not netId then
        Utils.notify({ type = 'error', description = 'Não foi possível sincronizar o veículo da cabine.' })
        return nil
    end

    local ok, response = lib.callback.await('mri_Qpaintjob:server:beginSession', false, boothId, netId)
    if not ok then
        Utils.notify({ type = 'error', description = response and response.message or 'A cabine está ocupada ou indisponível.' })
        return nil
    end

    local originalState = Utils.getVehiclePaintState(vehicle)
    if not originalState then
        TriggerServerEvent('mri_Qpaintjob:server:releaseSession', boothId, response.token, 'invalid_vehicle_state')
        Utils.notify({ type = 'error', description = 'Não foi possível ler o estado atual da pintura.' })
        return nil
    end

    State.activeSession = {
        boothId = boothId,
        boothName = Utils.getBoothName(boothId),
        token = response.token,
        vehicle = vehicle,
        vehicleNetId = netId,
        originalState = originalState,
        preview = Config.UI.PreviewEnabledByDefault,
        selection = {
            primary = cloneColor(originalState.primary),
            secondary = cloneColor(originalState.secondary),
            finish = originalState.finish,
        },
    }

    setupSessionCamera(State.activeSession)

    if State.activeSession.preview then
        Paint.applyPreview(State.activeSession)
    end

    return State.activeSession
end

function Paint.togglePreview()
    local session = State.activeSession
    if not session then return end

    session.preview = not session.preview
    if session.preview then
        Paint.applyPreview(session)
    else
        Paint.restoreOriginal(session)
    end
end

function Paint.updateSelection(kind, value)
    local session = State.activeSession
    if not session then return end

    if kind == 'finish' then
        session.selection.finish = tonumber(value) or session.selection.finish
    elseif kind == 'primary' or kind == 'secondary' then
        session.selection[kind] = value
    end

    if session.preview then
        Paint.applyPreview(session)
    end
end

function Paint.cancelSession(reason, silent)
    releaseSession(reason or 'cancelada', silent)
end

local function animateVehiclePaint(session, duration)
    local startTime = GetGameTimer()
    local original = session.originalState
    local finalSelection = session.selection

    CreateThread(function()
        while State.painter and State.painter.painting do
            local elapsed = GetGameTimer() - startTime
            local progress = math.min(1.0, elapsed / duration)
            local frameState = {
                primary = Utils.lerpColor(original.primary, finalSelection.primary, progress),
                secondary = Utils.lerpColor(original.secondary, finalSelection.secondary, progress),
                finish = finalSelection.finish,
                secondaryFinish = finalSelection.finish,
                primaryColorIndex = original.primaryColorIndex,
                secondaryColorIndex = original.secondaryColorIndex,
                pearlescentColor = original.pearlescentColor,
                wheelColor = original.wheelColor,
            }
            Utils.applyPaintState(session.vehicle, frameState)
            if progress >= 1.0 then break end
            Wait(100)
        end
    end)
end

function Paint.startProcess()
    local session = State.activeSession
    if not session then return false end
    if not Utils.isValidVehicle(session.vehicle) then
        Utils.notify({ type = 'error', description = 'O veículo não está mais disponível.' })
        releaseSession('veículo indisponível', true)
        return false
    end

    local boothVehiclePos = Utils.toVec3(Config.Locations[session.boothId].vehicle)
    if Utils.distance(GetEntityCoords(session.vehicle), boothVehiclePos) > Utils.getVehicleRadius(Config.Locations[session.boothId]) then
        Utils.notify({ type = 'error', description = 'O veículo saiu da posição correta da cabine.' })
        releaseSession('veículo fora da cabine', true)
        return false
    end

    local controlOk = Utils.requestControl(session.vehicle, 2000)
    if not controlOk then
        Utils.notify({ type = 'error', description = 'Não foi possível obter controle do veículo para pintar.' })
        return false
    end

    local confirmed = lib.alertDialog({
        header = Config.UI.Title,
        content = ('Confirmar pintura premium em **%s**?\n\nCabine: **%s**\nAcabamento: **%s**'):format(Utils.getVehicleDisplayName(session.vehicle), session.boothName, Utils.getFinishByValue(session.selection.finish).label),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Iniciar pintura',
            cancel = 'Voltar',
        },
    })

    if confirmed ~= 'confirm' then
        return false
    end

    local ok, response = lib.callback.await('mri_Qpaintjob:server:startPaint', false, session.boothId, session.token, session.vehicleNetId, session.selection)
    if not ok then
        Utils.notify({ type = 'error', description = response and response.message or 'Falha ao iniciar a pintura.' })
        return false
    end

    State.painter = State.painter or {}
    State.painter.painting = true

    FreezeEntityPosition(session.vehicle, true)
    animateVehiclePaint(session, Config.PaintDuration)

    local success = lib.progressBar({
        duration = Config.PaintDuration,
        label = Config.UI.ProgressLabel,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },
    })

    State.painter.painting = false
    FreezeEntityPosition(session.vehicle, false)
    Effects.stopBooth(session.boothId)

    if success then
        Paint.applyPreview(session)
        TriggerServerEvent('mri_Qpaintjob:server:finishPaint', session.boothId, session.token, true)
        destroySessionCamera()
        Utils.notify({ type = 'success', description = 'Pintura aplicada com sucesso.' })
        State.activeSession = nil
        State.painter = nil
        return true
    end

    Paint.restoreOriginal(session)
    TriggerServerEvent('mri_Qpaintjob:server:finishPaint', session.boothId, session.token, false)
    destroySessionCamera()
    Utils.notify({ type = 'warning', description = 'Pintura cancelada. O veículo foi restaurado.' })
    State.activeSession = nil
    State.painter = nil
    return false
end

RegisterNetEvent('mri_Qpaintjob:client:setBoothBusy', function(boothId, state)
    State.busyBooths[boothId] = state == true
end)

RegisterNetEvent('mri_Qpaintjob:client:playEffects', function(boothId, vehicleNetId, color)
    local booth = Utils.getBooth(boothId)
    if not booth then return end
    local pedCoords = GetEntityCoords(cache.ped)
    if Utils.distance(pedCoords, booth.control) > 70.0 then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not Utils.isValidVehicle(vehicle) then return end

    Effects.startBooth(boothId, vehicle, color)
end)

RegisterNetEvent('mri_Qpaintjob:client:stopEffects', function(boothId)
    Effects.stopBooth(boothId)
end)

CreateThread(function()
    while true do
        local session = State.activeSession
        if session then
            local booth = Utils.getBooth(session.boothId)
            local pedCoords = GetEntityCoords(cache.ped)
            if not booth or not Utils.isValidVehicle(session.vehicle) then
                releaseSession('estado inválido', true)
            elseif Utils.distance(pedCoords, booth.control) > Config.UI.SessionBreakDistance then
                releaseSession('você se afastou da cabine', false)
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

RegisterNetEvent('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    releaseSession('resource_stop', true)
    Effects.cleanupAll()
end)
