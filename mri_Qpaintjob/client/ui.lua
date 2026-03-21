Paintjob = Paintjob or {}
Paintjob.UI = Paintjob.UI or {}

local Utils = Paintjob.Utils
local Paint = Paintjob.Paint
local UI = Paintjob.UI

local MAIN_CONTEXT_ID = 'mri_qpaintjob:main'
local FINISH_CONTEXT_ID = 'mri_qpaintjob:finish'

local function sessionMetadata(session)
    return {
        { label = 'Cabine', value = session.boothName },
        { label = 'Veículo', value = Utils.getVehicleDisplayName(session.vehicle) },
        { label = 'Primária', value = Utils.rgbToHex(session.selection.primary) },
        { label = 'Secundária', value = Utils.rgbToHex(session.selection.secondary) },
        { label = 'Acabamento', value = Utils.getFinishByValue(session.selection.finish).label },
        { label = 'Preview', value = session.preview and 'Ativado' or 'Desativado' },
    }
end

local function reopenMainMenu()
    local session = Paintjob.State.activeSession
    if not session then return end
    UI.openMainMenu()
end

function UI.openColorDialog(kind)
    local session = Paintjob.State.activeSession
    if not session then return end

    local current = session.selection[kind]
    local input = lib.inputDialog(('%s • %s'):format(Config.UI.Title, kind == 'primary' and 'Pintura Primária' or 'Pintura Secundária'), {
        {
            type = 'color',
            label = 'Selecionar cor',
            default = Utils.rgbToHex(current),
            required = true,
        },
    })

    if not input then
        return reopenMainMenu()
    end

    Paint.updateSelection(kind, Utils.hexToRgb(input[1]))
    reopenMainMenu()
end

function UI.openFinishMenu()
    local session = Paintjob.State.activeSession
    if not session then return end

    local options = {}
    for _, finish in ipairs(Config.FinishTypes or {}) do
        options[#options + 1] = {
            title = finish.label,
            description = finish.description,
            icon = session.selection.finish == finish.value and 'circle-check' or 'circle',
            onSelect = function()
                Paint.updateSelection('finish', finish.value)
                reopenMainMenu()
            end,
        }
    end

    lib.registerContext({
        id = FINISH_CONTEXT_ID,
        title = 'Escolher acabamento',
        menu = MAIN_CONTEXT_ID,
        options = options,
    })

    lib.showContext(FINISH_CONTEXT_ID)
end

function UI.openMainMenu()
    local session = Paintjob.State.activeSession
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
            if Paintjob.State.activeSession then
                Paint.cancelSession('cancelada')
            end
        end,
        options = {
            {
                title = session.boothName,
                description = 'Painel premium da cabine de pintura',
                icon = Config.UI.Icon,
                readOnly = true,
                metadata = sessionMetadata(session),
            },
            {
                title = 'Pintura primária',
                description = 'Escolha a cor principal da carroceria.',
                icon = 'palette',
                metadata = {
                    { label = 'Cor atual', value = Utils.rgbToHex(session.selection.primary) },
                },
                onSelect = function()
                    UI.openColorDialog('primary')
                end,
            },
            {
                title = 'Pintura secundária',
                description = 'Escolha a cor secundária e detalhes.',
                icon = 'fill-drip',
                metadata = {
                    { label = 'Cor atual', value = Utils.rgbToHex(session.selection.secondary) },
                },
                onSelect = function()
                    UI.openColorDialog('secondary')
                end,
            },
            {
                title = 'Acabamento',
                description = 'Normal, metálico, perolado, fosco, metalizado ou cromado.',
                icon = 'wand-magic-sparkles',
                metadata = {
                    { label = 'Selecionado', value = Utils.getFinishByValue(session.selection.finish).label },
                },
                onSelect = UI.openFinishMenu,
            },
            {
                title = session.preview and 'Desativar preview' or 'Ativar preview',
                description = 'Visualize a pintura no veículo antes da confirmação final.',
                icon = session.preview and 'eye-slash' or 'eye',
                onSelect = function()
                    Paint.togglePreview()
                    reopenMainMenu()
                end,
            },
            {
                title = 'Confirmar pintura',
                description = 'Iniciar processo completo de pintura da cabine.',
                icon = 'circle-check',
                iconColor = 'green',
                onSelect = function()
                    Paintjob.State.suppressContextExit = true
                    lib.hideContext(true)
                    local finished = Paint.startProcess()
                    if not finished and Paintjob.State.activeSession then
                        UI.openMainMenu()
                    end
                end,
            },
            {
                title = 'Cancelar',
                description = 'Liberar a cabine e restaurar o veículo original.',
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
