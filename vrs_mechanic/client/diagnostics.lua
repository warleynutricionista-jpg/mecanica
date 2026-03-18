-- ============================================================
-- VRS_MECHANIC - DIAGNOSTICS CLIENT
-- ============================================================

--- Diagnóstico rápido (target no capô)
---@param vehicle number
function VRS.QuickDiagnostic(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_vehicle, type = 'error' })
        return
    end

    local plate = VRS.GetPlate(vehicle)
    if not plate then return end

    local status = VRS.GetLocalStatus(plate)
    if not status then
        lib.notify({ title = 'Erro', description = 'Não foi possível obter status.', type = 'error' })
        return
    end

    local serviceState = VRS.BeginContextualVehicleService(vehicle, nil, 'diagnostic', 'quick')
    if not serviceState then return end

    VRS.PlayAnimation('diagnostic')
    Wait(1000)
    VRS.StopAnimation()
    VRS.FinishContextualVehicleService(vehicle, serviceState)
    VRS.ShowDiagnosticMenu(vehicle, plate, status, false)
end

--- Diagnóstico completo (elevador / oficina)
---@param vehicle number
---@param shopId string
function VRS.FullDiagnostic(vehicle, shopId)
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({ title = 'Erro', description = VRS.L.repair.no_vehicle, type = 'error' })
        return
    end

    local plate = VRS.GetPlate(vehicle)
    if not plate then return end

    local serviceState = VRS.BeginContextualVehicleService(vehicle, shopId, 'diagnostic', 'full')
    if not serviceState then return end

    VRS.PlayAnimation('diagnostic')

    local success = lib.progressBar({
        duration = (serviceState and serviceState.context and serviceState.context.duration) or 3000,
        label = 'Inspecionando veículo...',
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

    -- Recarregar status do server
    local status = lib.callback.await('vrs_mechanic:server:getVehicleStatus', false, plate)
    if not status then return end
    VRS.VehicleStatus[plate] = status

    VRS.ShowDiagnosticMenu(vehicle, plate, status, true, shopId)
end

--- Mostra menu de diagnóstico
---@param vehicle number
---@param plate string
---@param status table
---@param fullMode boolean
---@param shopId string|nil
function VRS.ShowDiagnosticMenu(vehicle, plate, status, fullMode, shopId)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local options = {}

    -- Header com informações do veículo
    options[#options + 1] = {
        title = ('Placa: %s | Modelo: %s'):format(plate, model),
        description = fullMode and 'Diagnóstico completo' or 'Diagnóstico rápido',
        icon = 'fas fa-car',
        readOnly = true,
    }

    -- Status de cada parte
    for _, part in ipairs(VRS.Parts) do
        local value = status[part] or 0
        local pct = VRS.GetPartPercent(part, value)
        local color = VRS.GetStatusColor(pct)
        local label = VRS.GetPartLabel(part)

        local statusText
        if pct >= 70 then
            statusText = VRS.L.status.good
        elseif pct >= 30 then
            statusText = VRS.L.status.warning
        elseif pct > 0 then
            statusText = VRS.L.status.critical
        else
            statusText = VRS.L.status.broken
        end

        local icon = 'fas fa-check-circle'
        local iconColor = '#4CAF50'
        if color == 'yellow' then
            icon = 'fas fa-exclamation-triangle'
            iconColor = '#FF9800'
        elseif color == 'red' then
            icon = 'fas fa-times-circle'
            iconColor = '#F44336'
        end

        local desc = ('%d%% - %s'):format(pct, statusText)
        if pct < 30 then
            desc = desc .. ' | Necessita reparo!'
        elseif pct < 70 then
            desc = desc .. ' | Atenção'
        end

        options[#options + 1] = {
            title = label,
            description = desc,
            icon = icon,
            iconColor = iconColor,
            readOnly = true,
            progress = pct,
            colorScheme = color == 'green' and 'green' or (color == 'yellow' and 'yellow' or 'red'),
        }
    end

    -- Pneus (status separado)
    for i = 0, 3 do
        local burst = IsVehicleTyreBurst(vehicle, i, false)
        local label = ('Pneu %s'):format(i == 0 and 'Diant. Esq.' or i == 1 and 'Diant. Dir.' or i == 2 and 'Tras. Esq.' or 'Tras. Dir.')
        options[#options + 1] = {
            title = label,
            description = burst and 'Furado!' or 'OK',
            icon = burst and 'fas fa-times-circle' or 'fas fa-check-circle',
            iconColor = burst and '#F44336' or '#4CAF50',
            readOnly = true,
        }
    end

    -- Ações
    if fullMode and shopId then
        options[#options + 1] = {
            title = VRS.L.diagnostic.open_repair,
            description = 'Abrir menu de reparos para este veículo',
            icon = 'fas fa-tools',
            onSelect = function()
                VRS.OpenShopRepairMenu(vehicle, shopId)
            end,
        }

        options[#options + 1] = {
            title = VRS.L.diagnostic.create_work_order,
            description = 'Criar OS baseada no diagnóstico',
            icon = 'fas fa-file-alt',
            onSelect = function()
                VRS.CreateWorkOrderFromDiagnostic(vehicle, plate, status, shopId)
            end,
        }
    end

    lib.registerContext({
        id = 'vrs_diagnostic',
        title = VRS.L.diagnostic.title,
        options = options,
    })

    lib.showContext('vrs_diagnostic')
end

--- Criar OS a partir do diagnóstico
function VRS.CreateWorkOrderFromDiagnostic(vehicle, plate, status, shopId)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local problems = {}
    local materials = {}

    for _, part in ipairs(VRS.Parts) do
        local pct = VRS.GetPartPercent(part, status[part] or 0)
        if pct < 70 then
            problems[#problems + 1] = {
                part = part,
                label = VRS.GetPartLabel(part),
                percent = pct,
            }

            -- Adicionar materiais necessários
            local mats = Config.RepairMaterials[part]
            if mats then
                for _, mat in ipairs(mats) do
                    materials[#materials + 1] = {
                        item = mat.item,
                        amount = mat.amount,
                    }
                end
            end
        end
    end

    -- Calcular orçamento
    local prices = lib.callback.await('vrs_mechanic:server:getShopPrices', false, shopId)
    local budget = 0
    for _, prob in ipairs(problems) do
        budget = budget + (prices[prob.part] or 0)
    end

    -- Input para observações
    local input = lib.inputDialog('Nova Ordem de Serviço', {
        { type = 'input', label = 'Proprietário do veículo', placeholder = 'Nome do dono', required = false },
        { type = 'textarea', label = 'Observações', placeholder = 'Notas adicionais...', required = false },
    })

    if not input then return end

    local result = lib.callback.await('vrs_mechanic:server:createWorkOrder', false, {
        shopId = shopId,
        plate = plate,
        model = model,
        ownerName = input[1] or 'Desconhecido',
        problems = problems,
        materials = materials,
        budget = budget,
        notes = input[2] or '',
    })

    if result and result.success then
        lib.notify({
            title = 'Ordem de Serviço',
            description = ('OS #%d criada com sucesso!'):format(result.orderId),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Erro',
            description = 'Não foi possível criar a OS.',
            type = 'error',
        })
    end
end
