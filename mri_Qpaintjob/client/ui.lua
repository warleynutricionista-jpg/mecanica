Paintjob = Paintjob or {}
Paintjob.UI = Paintjob.UI or {}

local Utils = Paintjob.Utils
local Paint = Paintjob.Paint
local UI = Paintjob.UI

local MAIN_CONTEXT_ID = 'mri_qpaintjob:main'
local PREVIEW_CONTEXT_ID = 'mri_qpaintjob:preview'

local function getSession()
    return Paintjob.State.activeSession
end

local function sessionMetadata(session)
    return {
        { label = 'Cabine', value = session.boothName },
        { label = 'Veículo', value = Utils.getVehicleDisplayName(session.vehicle) },
        { label = 'Primária', value = ('%s • %s'):format(Utils.rgbToHex(session.selection.primary), Utils.rgbSwatch(session.selection.primary)) },
        { label = 'Secundária', value = ('%s • %s'):format(Utils.rgbToHex(session.selection.secondary), Utils.rgbSwatch(session.selection.secondary)) },
        { label = 'Acabamento', value = Utils.getFinishByValue(session.selection.finish).label },
        { label = 'Preview', value = session.preview and 'Ativado' or 'Desativado' },
    }
end

local function selectionSummary(session)
    return {
        { label = 'Cabine', value = session.boothName },
        { label = 'Veículo', value = Utils.getVehicleDisplayName(session.vehicle) },
        { label = 'Cor primária', value = Utils.rgbToHex(session.selection.primary) },
        { label = 'Cor secundária', value = Utils.rgbToHex(session.selection.secondary) },
        { label = 'Acabamento', value = Utils.getFinishByValue(session.selection.finish).label },
    }
end

local function reopenMainMenu()
    if getSession() then
        UI.openMainMenu()
    end
end

function UI.openSelectionDialog()
    local session = getSession()
    if not session then return end

    local response = lib.inputDialog(('%s • Configuração Premium'):format(Config.UI.Title), {
        {
            type = 'color',
            label = 'Pintura primária',
            description = 'Selecione a cor principal da carroceria.',
            default = Utils.rgbToHex(session.selection.primary),
            required = true,
        },
        {
            type = 'color',
            label = 'Pintura secundária',
            description = 'Selecione a cor secundária e detalhes.',
            default = Utils.rgbToHex(session.selection.secondary),
            required = true,
        },
        {
            type = 'select',
            label = 'Acabamento',
            description = 'Escolha o acabamento final da pintura.',
            options = Utils.getFinishOptions(),
            default = session.selection.finish,
            required = true,
        },
        {
            type = 'checkbox',
            label = 'Ativar preview ao salvar',
            description = 'Mostra a nova cor no veículo antes da confirmação final.',
            checked = session.preview,
        },
    })

    if not response then
        return reopenMainMenu()
    end

    Paint.updateSelection('primary', Utils.hexToRgb(response[1]))
    Paint.updateSelection('secondary', Utils.hexToRgb(response[2]))
    Paint.updateSelection('finish', tonumber(response[3]) or session.selection.finish)
    Paint.setPreviewEnabled(response[4] == true)

    UI.openPreviewMenu()
end

function UI.openPreviewMenu()
    local session = getSession()
    if not session then return end

    lib.registerContext({
        id = PREVIEW_CONTEXT_ID,
        title = 'Revisão da Pintura',
        menu = MAIN_CONTEXT_ID,
        options = {
            {
                title = 'Resumo da aplicação',
                description = 'Confira as cores e o acabamento antes de iniciar a cabine.',
                icon = 'car-side',
                readOnly = true,
                metadata = selectionSummary(session),
            },
            {
                title = session.preview and 'Ocultar preview' or 'Mostrar preview',
                description = 'Alterna a visualização prévia sem perder a seleção atual.',
                icon = session.preview and 'eye-slash' or 'eye',
                onSelect = function()
                    Paint.togglePreview()
                    UI.openPreviewMenu()
                end,
            },
            {
                title = 'Editar seleção',
                description = 'Voltar para alterar cor primária, secundária ou acabamento.',
                icon = 'sliders',
                onSelect = UI.openSelectionDialog,
            },
            {
                title = 'Iniciar pintura premium',
                description = 'Confirma, bloqueia a cabine e executa o processo completo.',
                icon = 'circle-check',
                iconColor = 'green',
                onSelect = function()
                    Paintjob.State.suppressContextExit = true
                    lib.hideContext(true)
                    local finished = Paint.startProcess()
                    if not finished and getSession() then
                        UI.openMainMenu()
                    end
                end,
            },
        },
    })

    lib.showContext(PREVIEW_CONTEXT_ID)
end

function UI.openMainMenu()
    local session = getSession()
    if not session then return end

    lib.registerContext({
        id = MAIN_CONTEXT_ID,
        title = Config.UI.Title,
        canClose = true,
        onExit = function()
            if Paintjob.State.suppressContextExit then
                Paintjob.State.suppressContextExit = false
                return
            end
            if getSession() then
                Paint.cancelSession('cancelada')
            end
        end,
        options = {
            {
                title = session.boothName,
                description = Config.UI.Subtitle,
                icon = Config.UI.Icon,
                readOnly = true,
                metadata = sessionMetadata(session),
            },
            {
                title = 'Configurar pintura',
                description = 'Escolha pintura primária, secundária, acabamento e preview.',
                icon = 'palette',
                onSelect = UI.openSelectionDialog,
            },
            {
                title = 'Revisar preview',
                description = 'Abrir resumo visual e validar o resultado antes de aplicar.',
                icon = 'magnifying-glass',
                onSelect = UI.openPreviewMenu,
            },
            {
                title = 'Cancelar sessão',
                description = 'Libera a cabine, limpa efeitos e restaura o veículo original.',
                icon = 'ban',
                iconColor = 'red',
                onSelect = function()
                    Paint.cancelSession('cancelada', true)
                end,
            },
        },
    })

    lib.showContext(MAIN_CONTEXT_ID)
end
