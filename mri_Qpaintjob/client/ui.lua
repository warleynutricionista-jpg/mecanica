Paintjob = Paintjob or {}
Paintjob.UI = Paintjob.UI or {}

local Utils = Paintjob.Utils
local Paint = Paintjob.Paint
local UI = Paintjob.UI

local MAIN_CONTEXT_ID = 'mri_qpaintjob:main'
local FINISH_CONTEXT_ID = 'mri_qpaintjob:finish'

local function getFinish(session)
    return Utils.getFinishByValue(session.selection.finish)
end

local function formatHex(hex)
    return ('`%s`'):format(hex)
end

local function formatRgb(rgb)
    return ('R:%s G:%s B:%s'):format(rgb.r or 0, rgb.g or 0, rgb.b or 0)
end

local function sessionMetadata(session)
    local finish = getFinish(session)
    local primaryHex = Utils.rgbToHex(session.selection.primary)
    local secondaryHex = Utils.rgbToHex(session.selection.secondary)

    return {
        { label = 'Cabine', value = session.boothName },
        { label = 'Veículo', value = Utils.getVehicleDisplayName(session.vehicle) },
        { label = 'Primária', value = primaryHex },
        { label = 'Secundária', value = secondaryHex },
        { label = 'Acabamento', value = finish.label },
        { label = 'Preview', value = session.preview and 'Ativado' or 'Desativado' },
    }
end

local function heroDescription(session)
    local finish = getFinish(session)
    local primaryHex = Utils.rgbToHex(session.selection.primary)
    local secondaryHex = Utils.rgbToHex(session.selection.secondary)

    return table.concat({
        Config.UI.Subtitle or 'Sistema premium de repintura automotiva',
        ('**Cabine:** %s'):format(session.boothName),
        ('**Veículo:** %s'):format(Utils.getVehicleDisplayName(session.vehicle)),
        ('**Primária:** %s  •  **Secundária:** %s'):format(formatHex(primaryHex), formatHex(secondaryHex)),
        ('**Acabamento:** %s  •  **Preview:** %s'):format(finish.label, session.preview and 'Ligado' or 'Desligado'),
    }, '\n')
end

local function colorCardMetadata(rgb)
    return {
        { label = 'HEX', value = Utils.rgbToHex(rgb) },
        { label = 'RGB', value = formatRgb(rgb) },
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
    local label = kind == 'primary' and 'Pintura Primária' or 'Pintura Secundária'
    local helper = kind == 'primary'
        and 'Defina a cor principal da carroceria. O preview mostra o resultado no veículo em tempo real.'
        or 'Defina a cor secundária para detalhes e contraste visual. O preview é atualizado imediatamente.'

    local input = lib.inputDialog(('%s • %s'):format(Config.UI.Title, label), {
        {
            type = 'color',
            label = 'Selecionar cor',
            description = helper,
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
            iconColor = session.selection.finish == finish.value and 'green' or nil,
            metadata = {
                { label = 'Categoria', value = 'Acabamento premium' },
                { label = 'Seleção atual', value = session.selection.finish == finish.value and 'Ativo' or 'Disponível' },
            },
            onSelect = function()
                Paint.updateSelection('finish', finish.value)
                reopenMainMenu()
            end,
        }
    end

    lib.registerContext({
        id = FINISH_CONTEXT_ID,
        title = ('%s • Acabamento'):format(Config.UI.Title),
        menu = MAIN_CONTEXT_ID,
        options = options,
    })

    lib.showContext(FINISH_CONTEXT_ID)
end

function UI.openMainMenu()
    local session = Paintjob.State.activeSession
    if not session then return end

    local finish = getFinish(session)
    local primaryHex = Utils.rgbToHex(session.selection.primary)
    local secondaryHex = Utils.rgbToHex(session.selection.secondary)

    lib.registerContext({
        id = MAIN_CONTEXT_ID,
        title = ('%s • %s'):format(Config.UI.Title, session.boothName),
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
                title = 'Projeto de Pintura Premium',
                description = heroDescription(session),
                icon = Config.UI.Icon,
                iconColor = 'blue',
                readOnly = true,
                metadata = sessionMetadata(session),
            },
            {
                title = ('Cor Primária • %s'):format(primaryHex),
                description = 'Escolha a cor principal da carroceria com preview imediato e leitura visual mais clara.',
                icon = 'palette',
                iconColor = 'blue',
                metadata = colorCardMetadata(session.selection.primary),
                onSelect = function()
                    UI.openColorDialog('primary')
                end,
            },
            {
                title = ('Cor Secundária • %s'):format(secondaryHex),
                description = 'Defina a segunda camada visual do projeto, ideal para detalhes, faixas e contraste.',
                icon = 'fill-drip',
                iconColor = 'violet',
                metadata = colorCardMetadata(session.selection.secondary),
                onSelect = function()
                    UI.openColorDialog('secondary')
                end,
            },
            {
                title = ('Acabamento • %s'):format(finish.label),
                description = finish.description,
                icon = 'wand-magic-sparkles',
                iconColor = 'yellow',
                metadata = {
                    { label = 'Perfil', value = finish.key },
                    { label = 'Aplicação', value = 'Primária e secundária' },
                },
                onSelect = UI.openFinishMenu,
            },
            {
                title = session.preview and 'Preview Ativo' or 'Preview Desativado',
                description = session.preview
                    and 'O veículo está mostrando as escolhas atuais em tempo real antes da pintura final.'
                    or 'Ative para visualizar imediatamente as escolhas de cor e acabamento no veículo.',
                icon = session.preview and 'eye' or 'eye-slash',
                iconColor = session.preview and 'green' or 'gray',
                metadata = {
                    { label = 'Status', value = session.preview and 'Ligado' or 'Desligado' },
                    { label = 'Efeito', value = 'Pré-visualização instantânea' },
                },
                onSelect = function()
                    Paint.togglePreview()
                    reopenMainMenu()
                end,
            },
            {
                title = 'Iniciar Pintura Premium',
                description = 'Confirmar o projeto e iniciar a aplicação completa da pintura na cabine.',
                icon = 'circle-check',
                iconColor = 'green',
                metadata = {
                    { label = 'Primária', value = primaryHex },
                    { label = 'Secundária', value = secondaryHex },
                    { label = 'Acabamento', value = finish.label },
                },
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
                title = 'Cancelar Sessão',
                description = 'Liberar a cabine imediatamente e restaurar a aparência original do veículo.',
                icon = 'ban',
                iconColor = 'red',
                metadata = {
                    { label = 'Ação', value = 'Libera a cabine' },
                    { label = 'Segurança', value = 'Restaura pintura original' },
                },
                onSelect = function()
                    Paint.cancelSession('cancelada', true)
                end,
            },
        },
    })

    lib.showContext(MAIN_CONTEXT_ID)
end
