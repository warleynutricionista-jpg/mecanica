-- ============================================================
-- VRS_MECHANIC - LIFT ADMIN CLIENT
-- ============================================================

local editorState = nil
local adminCommandsRegistered = false


function VRS.FetchLiftAdminData()
    local ok, response = pcall(function()
        return lib.callback.await('vrs_mechanic:server:getLiftLayouts', false)
    end)

    if not ok then
        print(('[vrs_mechanic] Lift admin callback indisponível: %s'):format(response))
        return nil
    end

    return response
end

local function registerLiftAdminCommands()
    if adminCommandsRegistered then return end

    local configured = Config.Lift.AdminCommands
    local commands = {}

    if type(configured) == 'table' and #configured > 0 then
        commands = configured
    else
        commands = {
            Config.Lift.AdminCommand or 'liftadmin',
            'elevadorcarro',
        }
    end

    local seen = {}
    for _, commandName in ipairs(commands) do
        if type(commandName) == 'string' and commandName ~= '' and not seen[commandName] then
            seen[commandName] = true
            RegisterCommand(commandName, function()
                VRS.OpenLiftAdminMenu()
            end, false)
        end
    end

    adminCommandsRegistered = true
end

local function round3(value)
    return tonumber(('%0.3f'):format(value or 0.0)) or 0.0
end

local function serializeVec3(value)
    if not value then return nil end
    return { x = value.x, y = value.y, z = value.z }
end

local function prepareModel(model)
    local hash = VRS.ResolveModelHash(model, 'client.lift_admin.prepareModel')
    if not hash then return nil end
    if HasModelLoaded(hash) then return hash end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end

    return hash
end

local function createPreviewProp(model, coords, heading)
    local hash = prepareModel(model)
    if not IsModelValid(hash) then return nil end

    local entity = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    if entity and entity ~= 0 then
        SetEntityAsMissionEntity(entity, true, true)
        FreezeEntityPosition(entity, true)
        SetEntityCollision(entity, false, false)
        SetEntityAlpha(entity, Config.Lift.Editor.previewAlpha or 170, false)
        SetEntityInvincible(entity, true)
        SetEntityHeading(entity, heading or 0.0)
    end

    return entity
end

local function destroyPreview(preview)
    if not preview then return end

    if preview.platform and DoesEntityExist(preview.platform) then
        DeleteEntity(preview.platform)
    end

    for _, pole in ipairs(preview.poles or {}) do
        if pole and DoesEntityExist(pole) then
            DeleteEntity(pole)
        end
    end

    if preview.elecbox and DoesEntityExist(preview.elecbox) then
        DeleteEntity(preview.elecbox)
    end
end

local function createLiftPreview(coords, heading, modelName)
    local profile = VRS.GetLiftModelProfile(modelName or Config.Lift.DefaultModelName)
    local primaryModel = profile.platformModel or profile.model or Config.Lift.PlatformModel
    local platform = createPreviewProp(primaryModel, coords, heading)
    if not platform or platform == 0 then return nil end

    if profile.sourceType ~= 'spawned_composite' and (modelName and modelName ~= 'standard_lift') then
        return {
            platform = platform,
            poles = {},
            elecbox = nil,
            composite = false,
            model = modelName,
            profile = profile,
        }
    end

    local poles = {}
    if profile.spawnPoles ~= false and Config.Lift.SpawnPoles then
        local offsets = {
            vec3(1.43, -2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(-1.43, -2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(-1.43, 2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(1.43, 2.88, Config.Lift.PoleZOffset or -0.30),
        }

        for i, offset in ipairs(offsets) do
            local poleCoords = GetOffsetFromEntityInWorldCoords(platform, offset.x, offset.y, offset.z)
            local poleHeading = (i == 1 or i == 4) and (heading - 180.0) or heading
            poles[#poles + 1] = createPreviewProp(profile.poleModel or Config.Lift.PoleModel, poleCoords, poleHeading)
        end
    end

    local elecbox = nil
    if profile.spawnElecBox ~= false and Config.Lift.SpawnElecBox then
        local offset = profile.elecBoxOffset or Config.Lift.ElecBoxOffset or vec3(0.0, -3.3, -0.7)
        local elecCoords = GetOffsetFromEntityInWorldCoords(platform, offset.x, offset.y, offset.z)
        elecbox = createPreviewProp(profile.elecBoxModel or Config.Lift.ElecBoxModel, elecCoords, heading)
    end

    return {
        platform = platform,
        poles = poles,
        elecbox = elecbox,
        composite = true,
        model = modelName,
        profile = profile,
    }
end

local function setPreviewTransform(preview, coords, heading)
    if not preview or not preview.platform or not DoesEntityExist(preview.platform) then return end

    SetEntityCoordsNoOffset(preview.platform, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(preview.platform, heading)

    if preview.composite and Config.Lift.SpawnPoles then
        local offsets = {
            vec3(1.43, -2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(-1.43, -2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(-1.43, 2.88, Config.Lift.PoleZOffset or -0.30),
            vec3(1.43, 2.88, Config.Lift.PoleZOffset or -0.30),
        }
        for index, pole in ipairs(preview.poles or {}) do
            if pole and DoesEntityExist(pole) then
                local offset = offsets[index]
                local poleCoords = GetOffsetFromEntityInWorldCoords(preview.platform, offset.x, offset.y, offset.z)
                local poleHeading = (index == 1 or index == 4) and (heading - 180.0) or heading
                SetEntityCoordsNoOffset(pole, poleCoords.x, poleCoords.y, poleCoords.z, false, false, false)
                SetEntityHeading(pole, poleHeading)
            end
        end
    end

    if preview.elecbox and DoesEntityExist(preview.elecbox) then
        local offset = (preview.profile and preview.profile.elecBoxOffset) or Config.Lift.ElecBoxOffset or vec3(0.0, -3.3, -0.7)
        local elecCoords = GetOffsetFromEntityInWorldCoords(preview.platform, offset.x, offset.y, offset.z)
        SetEntityCoordsNoOffset(preview.elecbox, elecCoords.x, elecCoords.y, elecCoords.z, false, false, false)
        SetEntityHeading(preview.elecbox, heading)
    end
end

local function drawEditorHelp(lines)
    SetTextFont(4)
    SetTextScale(0.33, 0.33)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()

    local y = 0.78
    for _, line in ipairs(lines) do
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(0.015, y)
        y = y + 0.022
    end
end

local function getGroundZ(coords)
    local probeZ = math.max(coords.z + 5.0, 100.0)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, probeZ, false)
    if not found then
        found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, probeZ, true)
    end
    return found and groundZ or coords.z
end

local function getShopDistance(shopId, coords)
    local shop = Config.Shops[shopId]
    if not shop or not shop.zones or not shop.zones.main then return 9999.0 end
    return #(vec3(coords.x, coords.y, coords.z) - shop.zones.main.coords)
end

local function findNearestLiftInShop(shopId, maxDistance)
    local pedCoords = GetEntityCoords(cache.ped)
    local shop = Config.Shops[shopId]
    if not shop or not shop.lifts then return nil end

    local bestLift, bestDist = nil, maxDistance or 9999.0
    for _, lift in ipairs(shop.lifts) do
        local coords = vec3(lift.coords.x, lift.coords.y, lift.coords.z)
        local dist = #(pedCoords - coords)
        if dist <= bestDist then
            bestLift = lift
            bestDist = dist
        end
    end

    return bestLift, bestDist
end

local function getPlacementValidation(shopId, liftId, coords)
    local distanceLimit = Config.Lift.ValidationDistanceFromShop or 35.0
    local minSpacing = Config.Lift.MinSpacing or 4.0
    local maxGroundDelta = Config.Lift.MaxGroundDelta or 0.45
    local groundZ = getGroundZ(coords)
    local verticalDelta = math.abs(coords.z - groundZ)

    if getShopDistance(shopId, coords) > distanceLimit then
        return false, ('Fora da área permitida da oficina (máx. %.1fm).'):format(distanceLimit)
    end

    if verticalDelta > maxGroundDelta then
        return false, ('Altura desalinhada do chão (delta %.2f).'):format(verticalDelta)
    end

    local occupied = IsPositionOccupied(coords.x, coords.y, coords.z + 0.8, 1.2, false, false, false, false, true, 0, false)
    if occupied then
        return false, 'Local bloqueado por parede/objeto.'
    end

    local shop = Config.Shops[shopId]
    for _, lift in ipairs(shop and shop.lifts or {}) do
        if lift.id ~= liftId then
            local dist = #(vec3(coords.x, coords.y, coords.z) - vec3(lift.coords.x, lift.coords.y, lift.coords.z))
            if dist < minSpacing then
                return false, ('Muito próximo de outro elevador (mín. %.1fm).'):format(minSpacing)
            end
        end
    end

    return true, 'Posição válida.'
end

local function openLiftListMenu(shopId)
    local shop = Config.Shops[shopId]
    if not shop then return end

    local options = {}
    for _, lift in ipairs(shop.lifts or {}) do
        options[#options + 1] = {
            title = ('%s (%s)'):format(lift.id, lift.source == 'custom' and 'custom' or 'config'),
            description = ('XYZ %.2f, %.2f, %.2f | H %.2f'):format(lift.coords.x, lift.coords.y, lift.coords.z, lift.coords.w or 0.0),
            icon = 'fas fa-elevator',
            onSelect = function()
                VRS.OpenLiftAdminMenu(shopId, lift.id)
            end,
        }
    end

    if #options == 0 then
        options[1] = {
            title = 'Nenhum elevador cadastrado',
            icon = 'fas fa-circle-info',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = ('vrs_lift_admin_list_%s'):format(shopId),
        title = ('Elevadores - %s'):format(shop.label),
        menu = ('vrs_lift_admin_shop_%s'):format(shopId),
        options = options,
    })

    lib.showContext(('vrs_lift_admin_list_%s'):format(shopId))
end

local function saveLiftLayout(payload)
    local result = lib.callback.await('vrs_mechanic:server:saveLiftLayout', false, payload)
    if not result or not result.success then
        local messages = {
            no_access = 'Sem permissão para gerenciar elevadores.',
            no_permission = 'Sem permissão para gerenciar elevadores.',
            not_on_duty = 'Você precisa estar em serviço para gerenciar elevadores.',
            shop_busy = 'Existe um elevador em uso/movimento nesta oficina.',
            invalid_lift = 'Elevador inválido.',
            invalid_payload = 'Dados inválidos para salvar.',
            admin_unavailable = 'Gerenciamento de elevadores indisponível no servidor.',
            cooldown = 'Aguarde um instante antes de tentar novamente.',
            outside_shop = 'A nova posição está fora da área permitida da oficina.',
            lift_overlap = 'A nova posição está muito próxima de outro elevador.',
        }
        lib.notify({ title = 'Elevador', description = messages[result and result.reason or ''] or 'Falha ao salvar elevador.', type = 'error' })
        return false
    end

    if result.layouts then
        VRS.ApplyLiftLayouts(result.layouts)
    end

    lib.notify({ title = 'Elevador', description = 'Posição salva com sucesso.', type = 'success' })
    return true
end

local function deleteLiftLayout(shopId, liftId)
    local result = lib.callback.await('vrs_mechanic:server:deleteLiftLayout', false, shopId, liftId)
    if not result or not result.success then
        local messages = {
            no_access = 'Sem permissão para remover elevadores.',
            no_permission = 'Sem permissão para remover elevadores.',
            not_on_duty = 'Você precisa estar em serviço para gerenciar elevadores.',
            shop_busy = 'Existe um elevador em uso/movimento nesta oficina.',
            invalid_lift = 'Elevador inválido.',
            admin_unavailable = 'Gerenciamento de elevadores indisponível no servidor.',
            cooldown = 'Aguarde um instante antes de tentar novamente.',
        }
        lib.notify({ title = 'Elevador', description = messages[result and result.reason or ''] or 'Falha ao remover elevador.', type = 'error' })
        return false
    end

    if result.layouts then
        VRS.ApplyLiftLayouts(result.layouts)
    end

    lib.notify({ title = 'Elevador', description = 'Elevador removido com sucesso.', type = 'success' })
    return true
end

local function startLiftEditor(shopId, existingLift, requestedModel)
    if editorState then return end

    local shop = Config.Shops[shopId]
    if not shop then return end

    local startCoords
    local startHeading

    if existingLift then
        startCoords = vec3(existingLift.coords.x, existingLift.coords.y, existingLift.coords.z)
        startHeading = existingLift.coords.w or 0.0
    else
        local pedCoords = GetEntityCoords(cache.ped)
        local groundZ = getGroundZ(pedCoords)
        startCoords = vec3(pedCoords.x, pedCoords.y, groundZ)
        startHeading = GetEntityHeading(cache.ped)
    end

    local preview = createLiftPreview(startCoords, startHeading, requestedModel or (existingLift and existingLift.model) or Config.Lift.DefaultModelName)
    if not preview then
        lib.notify({ title = 'Elevador', description = 'Não foi possível criar o preview do elevador.', type = 'error' })
        return
    end

    editorState = {
        shopId = shopId,
        lift = existingLift,
        preview = preview,
        requestedModel = requestedModel or (existingLift and existingLift.model) or Config.Lift.DefaultModelName,
        heading = startHeading,
        baseCoords = startCoords,
        zOffset = startCoords.z - getGroundZ(startCoords),
        valid = false,
        reason = 'Carregando validação...',
        lastValidation = 0,
    }

    lib.notify({ title = 'Elevador', description = 'Modo de edição iniciado. ENTER confirma e BACKSPACE cancela.', type = 'inform' })

    CreateThread(function()
        while editorState do
            Wait(0)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 191, true)
            DisableControlAction(0, 10, true)
            DisableControlAction(0, 11, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)

            local fine = IsDisabledControlPressed(0, 21)
            local moveStep = fine and (Config.Lift.Editor.fineMoveSpeed or 0.01) or (Config.Lift.Editor.moveSpeed or 0.03)
            local rotStep = fine and ((Config.Lift.Editor.rotationSpeed or 1.5) * 0.5) or (Config.Lift.Editor.rotationSpeed or 1.5)
            local verticalStep = fine and ((Config.Lift.Editor.verticalSpeed or 0.02) * 0.5) or (Config.Lift.Editor.verticalSpeed or 0.02)

            local forward = vec3(math.sin(math.rad(editorState.heading)), math.cos(math.rad(editorState.heading)), 0.0)
            local right = vec3(math.cos(math.rad(editorState.heading)), -math.sin(math.rad(editorState.heading)), 0.0)

            if IsDisabledControlPressed(0, 32) or IsDisabledControlPressed(0, 172) then
                editorState.baseCoords = editorState.baseCoords + (forward * moveStep)
            end
            if IsDisabledControlPressed(0, 33) or IsDisabledControlPressed(0, 173) then
                editorState.baseCoords = editorState.baseCoords - (forward * moveStep)
            end
            if IsDisabledControlPressed(0, 34) or IsDisabledControlPressed(0, 174) then
                editorState.baseCoords = editorState.baseCoords - (right * moveStep)
            end
            if IsDisabledControlPressed(0, 35) or IsDisabledControlPressed(0, 175) then
                editorState.baseCoords = editorState.baseCoords + (right * moveStep)
            end
            if IsDisabledControlPressed(0, 44) or IsDisabledControlPressed(0, 14) then
                editorState.heading = (editorState.heading + rotStep) % 360.0
            end
            if IsDisabledControlPressed(0, 38) or IsDisabledControlPressed(0, 15) then
                editorState.heading = (editorState.heading - rotStep) % 360.0
            end
            if IsDisabledControlPressed(0, 10) then
                editorState.zOffset = editorState.zOffset + verticalStep
            end
            if IsDisabledControlPressed(0, 11) then
                editorState.zOffset = editorState.zOffset - verticalStep
            end

            local snappedGround = getGroundZ(editorState.baseCoords)
            local finalCoords = vec3(editorState.baseCoords.x, editorState.baseCoords.y, snappedGround + editorState.zOffset)
            editorState.finalCoords = finalCoords

            setPreviewTransform(editorState.preview, finalCoords, editorState.heading)

            if GetGameTimer() >= editorState.lastValidation then
                editorState.valid, editorState.reason = getPlacementValidation(editorState.shopId, editorState.lift and editorState.lift.id or nil, finalCoords)
                editorState.lastValidation = GetGameTimer() + (Config.Lift.Editor.refreshInterval or 150)
            end

            if IsDisabledControlJustPressed(0, 191) then
                if not editorState.valid then
                    lib.notify({ title = 'Elevador', description = editorState.reason or 'Local inválido.', type = 'error' })
                else
                    local payload = {
                        shopId = editorState.shopId,
                        liftId = editorState.lift and editorState.lift.id or nil,
                        model = editorState.lift and editorState.lift.model or editorState.requestedModel or Config.Lift.DefaultModelName,
                        ownerJob = shop.job,
                        category = editorState.shopId,
                        length = editorState.lift and editorState.lift.length or 5.0,
                        width = editorState.lift and editorState.lift.width or 2.5,
                        metadata = editorState.lift and editorState.lift.metadata or {},
                        minHeight = (editorState.lift and editorState.lift.minHeight) or (preview.profile and preview.profile.minHeight) or Config.Lift.MinHeight,
                        maxHeight = (editorState.lift and editorState.lift.maxHeight) or (preview.profile and preview.profile.maxHeight) or Config.Lift.MaxHeight,
                        sourceType = (editorState.lift and editorState.lift.sourceType) or (preview.profile and preview.profile.sourceType) or 'spawned',
                        useExistingEntity = (editorState.lift and editorState.lift.useExistingEntity) or false,
                        platformOffset = serializeVec3((editorState.lift and editorState.lift.platformOffset) or (preview.profile and preview.profile.platformOffset) or vec3(0.0, 0.0, 0.0)),
                        vehicleOffset = serializeVec3((editorState.lift and editorState.lift.vehicleOffset) or (preview.profile and preview.profile.vehicleOffset) or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36)),
                        interactionOffset = serializeVec3((editorState.lift and editorState.lift.interactionOffset) or (preview.profile and preview.profile.interactionOffset) or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0)),
                        coords = {
                            x = round3(finalCoords.x),
                            y = round3(finalCoords.y),
                            z = round3(finalCoords.z),
                            w = round3(editorState.heading),
                        },
                        heading = round3(editorState.heading),
                    }
                    destroyPreview(editorState.preview)
                    editorState = nil
                    saveLiftLayout(payload)
                    break
                end
            end

            if IsDisabledControlJustPressed(0, 177) then
                destroyPreview(editorState.preview)
                editorState = nil
                lib.notify({ title = 'Elevador', description = 'Operação cancelada.', type = 'inform' })
                break
            end

            drawEditorHelp({
                ('~y~Editor de elevador~s~ | Oficina: %s'):format(shop.label),
                'WASD / setas: mover | Q/E ou scroll: rotacionar | PgUp/PgDn: subir/descer',
                'Segure SHIFT para ajuste fino.',
                ('Status: %s%s'):format(editorState.valid and '~g~' or '~r~', editorState.reason or '---'),
                ('Coords: %.2f %.2f %.2f | Heading: %.2f'):format(finalCoords.x, finalCoords.y, finalCoords.z, editorState.heading),
                '~g~ENTER~s~ confirmar | ~r~BACKSPACE~s~ cancelar',
            })
        end
    end)
end

local function selectLiftModelForCreation()
    local options = {}
    for profileName, profile in pairs(Config.Lift.Models or {}) do
        options[#options + 1] = {
            label = profile.label or profileName,
            value = profile.model or profileName,
        }
    end

    table.sort(options, function(a, b)
        return a.label < b.label
    end)

    local selected = lib.inputDialog('Novo elevador', {
        {
            type = 'select',
            label = 'Modelo do elevador',
            options = options,
            default = Config.Lift.DefaultModelName,
            required = true,
        },
    })

    return selected and selected[1] or nil
end

local function openShopAdminMenu(shopId)
    local shop = Config.Shops[shopId]
    if not shop then return end

    local nearestLift = findNearestLiftInShop(shopId, Config.Lift.ValidationDistanceFromShop or 35.0)
    local options = {
        {
            title = 'Criar elevador',
            description = 'Criar um novo elevador usando o modo de posicionamento.',
            icon = 'fas fa-plus',
            onSelect = function()
                local selectedModel = selectLiftModelForCreation()
                if selectedModel then
                    startLiftEditor(shopId, nil, selectedModel)
                end
            end,
        },
        {
            title = 'Editar elevador próximo',
            description = nearestLift and ('Editar %s.'):format(nearestLift.id) or 'Nenhum elevador próximo encontrado.',
            icon = 'fas fa-pen',
            disabled = nearestLift == nil,
            onSelect = function()
                if nearestLift then
                    startLiftEditor(shopId, nearestLift)
                end
            end,
        },
        {
            title = 'Remover elevador próximo',
            description = nearestLift and ('Remover %s.'):format(nearestLift.id) or 'Nenhum elevador próximo encontrado.',
            icon = 'fas fa-trash',
            disabled = nearestLift == nil,
            onSelect = function()
                if not nearestLift then return end
                local confirmed = lib.alertDialog({
                    header = 'Remover elevador',
                    content = ('Deseja remover o elevador %s?'):format(nearestLift.id),
                    centered = true,
                    cancel = true,
                })
                if confirmed == 'confirm' then
                    deleteLiftLayout(shopId, nearestLift.id)
                end
            end,
        },
        {
            title = 'Listar elevadores',
            description = 'Selecionar um elevador por ID para editar ou remover.',
            icon = 'fas fa-list',
            onSelect = function()
                openLiftListMenu(shopId)
            end,
        },
    }

    lib.registerContext({
        id = ('vrs_lift_admin_shop_%s'):format(shopId),
        title = ('Gerenciar elevadores - %s'):format(shop.label),
        menu = 'vrs_lift_admin_root',
        options = options,
    })

    lib.showContext(('vrs_lift_admin_shop_%s'):format(shopId))
end

function VRS.OpenLiftAdminMenu(shopId, liftId)
    local response = VRS.FetchLiftAdminData()
    if not response then
        lib.notify({ title = 'Elevador', description = 'Gerenciamento de elevadores indisponível no servidor.', type = 'error' })
        return
    end

    local shops = response.shops or {}
    local layouts = response.layouts or nil

    if layouts then
        VRS.ApplyLiftLayouts(layouts)
    end

    if response.allowed == false or not shops or #shops == 0 then
        lib.notify({ title = 'Elevador', description = 'Sem permissão para gerenciar elevadores.', type = 'error' })
        return
    end

    if shopId and not liftId then
        openShopAdminMenu(shopId)
        return
    end

    if shopId and liftId then
        local shop = Config.Shops[shopId]
        if not shop then return end

        local lift = nil
        for _, entry in ipairs(shop.lifts or {}) do
            if entry.id == liftId then
                lift = entry
                break
            end
        end

        if not lift then
            lib.notify({ title = 'Elevador', description = 'Elevador inválido.', type = 'error' })
            return
        end

        lib.registerContext({
            id = 'vrs_lift_admin_target_actions',
            title = ('Gerenciar %s'):format(lift.id),
            options = {
                {
                    title = 'Reposicionar elevador',
                    description = 'Abrir modo de ajuste fino para este elevador.',
                    icon = 'fas fa-pen-ruler',
                    onSelect = function()
                        startLiftEditor(shopId, lift)
                    end,
                },
                {
                    title = 'Remover elevador',
                    description = 'Excluir o elevador selecionado.',
                    icon = 'fas fa-trash',
                    onSelect = function()
                        local confirmed = lib.alertDialog({
                            header = 'Remover elevador',
                            content = ('Deseja remover o elevador %s?'):format(lift.id),
                            centered = true,
                            cancel = true,
                        })
                        if confirmed == 'confirm' then
                            deleteLiftLayout(shopId, lift.id)
                        end
                    end,
                },
            },
        })

        lib.showContext('vrs_lift_admin_target_actions')
        return
    end

    local rootOptions = {}
    for _, shop in ipairs(shops) do
        rootOptions[#rootOptions + 1] = {
            title = shop.label,
            description = ('%d elevadores configurados.'):format(shop.liftCount or 0),
            icon = 'fas fa-warehouse',
            onSelect = function()
                openShopAdminMenu(shop.shopId)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_lift_admin_root',
        title = 'Gerenciamento de elevadores',
        options = rootOptions,
    })

    lib.showContext('vrs_lift_admin_root')
end


local function debugNearestLift()
    local shopId = VRS.CurrentShop or VRS.GetPlayerShopId()
    local lift = VRS.GetNearestCompatibleWorldLift and VRS.GetNearestCompatibleWorldLift(15.0, shopId)
    if not lift then
        lib.notify({ title = 'Lift Debug', description = 'Nenhum elevador compatível encontrado próximo.', type = 'error' })
        return
    end

    local vehicle, vehicleDist = VRS.GetClosestVehicle(8.0)
    local vehicleText = 'Sem veículo próximo'
    if vehicle then
        local vehCoords = GetEntityCoords(vehicle)
        vehicleText = ('Veículo %.2fm | offset %.2f %.2f %.2f'):format(
            vehicleDist or 0.0,
            vehCoords.x - lift.coords.x,
            vehCoords.y - lift.coords.y,
            vehCoords.z - lift.coords.z
        )
    end

    local snippet = table.concat({
        ('["%s"] = {'):format(lift.model),
        ('    model = "%s",'):format(lift.model),
        ('    label = "%s",'):format(lift.model),
        '    family = "generic",',
        '    sourceType = "world",',
        '    useExistingEntity = true,',
        ('    minHeight = %.2f,'):format(lift.minHeight or 0.0),
        ('    maxHeight = %.2f,'):format(lift.maxHeight or 2.1),
        ('    length = %.2f,'):format(lift.length or 5.0),
        ('    width = %.2f,'):format(lift.width or 2.5),
        ('    vehicleOffset = vec3(%.2f, %.2f, %.2f),'):format(
            (lift.vehicleOffset and lift.vehicleOffset.x or 0.0),
            (lift.vehicleOffset and lift.vehicleOffset.y or 0.0),
            (lift.vehicleOffset and lift.vehicleOffset.z or (Config.Lift.VehicleZOffset or 0.36))
        ),
        ('    platformOffset = vec3(%.2f, %.2f, %.2f),'):format(
            (lift.platformOffset and lift.platformOffset.x or 0.0),
            (lift.platformOffset and lift.platformOffset.y or 0.0),
            (lift.platformOffset and lift.platformOffset.z or 0.0)
        ),
        ('    interactionOffset = vec3(%.2f, %.2f, %.2f),'):format(
            (lift.interactionOffset and lift.interactionOffset.x or 1.9),
            (lift.interactionOffset and lift.interactionOffset.y or 0.0),
            (lift.interactionOffset and lift.interactionOffset.z or 0.0)
        ),
        '},',
    }, '\n')

    if lib.setClipboard then
        lib.setClipboard(snippet)
    end

    print(('[vrs_mechanic] Lift Debug | model=%s | coords=%.3f %.3f %.3f | heading=%.2f | size=%.2f x %.2f | %s'):format(
        lift.model,
        lift.coords.x,
        lift.coords.y,
        lift.coords.z,
        lift.coords.w or 0.0,
        lift.width or 0.0,
        lift.length or 0.0,
        vehicleText
    ))
    print(snippet)

    lib.notify({ title = 'Lift Debug', description = ('Modelo %s detectado. Snippet enviado para clipboard/console.'):format(lift.model), type = 'inform' })
end

registerLiftAdminCommands()

RegisterCommand(Config.Lift.DebugCommand or 'liftdebug', function()
    debugNearestLift()
end, false)
