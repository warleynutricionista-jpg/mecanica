-- ============================================================
-- UTILITÁRIOS COMPARTILHADOS
-- ============================================================

VRS = VRS or {}

--- Retorna se o modo debug está habilitado
---@param category string|nil
---@return boolean
function VRS.IsDebugEnabled(category)
    local debugModules = Config.DebugModules or {}
    if category and debugModules[category] ~= nil then
        return debugModules[category] == true
    end

    local debugConfig = Config.Debug or {}
    if category and debugConfig[category] ~= nil then
        return debugConfig[category] == true
    end

    return debugConfig.enabled == true
end

--- Retorna se um modo experimental está habilitado
---@param flag string
---@return boolean
function VRS.IsExperimentalEnabled(flag)
    if Config.SafeMode == true then
        return false
    end

    local experimental = Config.Experimental or {}
    return flag and experimental[flag] == true or false
end

--- Log de debug opcional e padronizado
---@param category string
---@param message string
function VRS.DebugLog(category, message)
    if not VRS.IsDebugEnabled(category) then return end
    print(('[vrs_mechanic][debug][%s] %s'):format(category or 'general', message or ''))
end

--- Mede e loga tempo de execução de um bloco/loop quando o debug estiver ativo
---@param category string
---@param label string
---@param startedAt number
function VRS.DebugMeasure(category, label, startedAt)
    if not startedAt or not VRS.IsDebugEnabled(category) then return end
    local elapsed = GetGameTimer() - startedAt
    VRS.DebugLog(category, ('%s levou %dms'):format(label or 'medição', elapsed))
end

--- Retorna o percentual de uma parte (0-100)
---@param part string
---@param value number
---@return number
function VRS.GetPartPercent(part, value)
    local max = Config.MaxStatus[part]
    if not max or max == 0 then return 0 end
    return math.floor((value / max) * 100 + 0.5)
end

--- Retorna a cor do status baseado no percentual
---@param percent number
---@return string -- 'green', 'yellow', 'red'
function VRS.GetStatusColor(percent)
    if percent >= 70 then return 'green'
    elseif percent >= 30 then return 'yellow'
    else return 'red' end
end

--- Retorna o label traduzido de uma parte
---@param part string
---@return string
function VRS.GetPartLabel(part)
    local locale = VRS.Locale
    if locale and locale.UI and locale.UI.parts and locale.UI.parts[part] then
        return locale.UI.parts[part]
    end
    return part
end

--- Clamp de valor entre min e max
---@param value number
---@param min number
---@param max number
---@return number
function VRS.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Verifica se uma parte é válida
---@param part string
---@return boolean
function VRS.IsValidPart(part)
    for _, p in ipairs(VRS.Parts) do
        if p == part then return true end
    end
    return false
end

--- Formata valor monetário em BRL
---@param amount number
---@return string
function VRS.FormatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1.%2')
        if k == 0 then break end
    end
    return formatted
end

--- Retorna status padrão de veículo novo
---@return table
function VRS.GetDefaultStatus()
    local status = {}
    for part, max in pairs(Config.MaxStatus) do
        status[part] = max
    end
    return status
end

--- Verifica se o valor está em uma tabela
---@param tbl table
---@param val any
---@return boolean
function VRS.TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

--- Retorna o label amigável de um item do inventário
---@param itemName string
---@return string
function VRS.GetItemLabel(itemName)
    if Config.PartsShop and Config.PartsShop.items and Config.PartsShop.items[itemName] and Config.PartsShop.items[itemName].label then
        return Config.PartsShop.items[itemName].label
    end

    return itemName
end



--- Faz deep copy simples de tabelas
---@param value any
---@return any
function VRS.DeepCopy(value)
    if type(value) ~= 'table' then return value end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = VRS.DeepCopy(entry)
    end
    return copy
end

local modelDebugCache = {}

local function summarizeDebugValue(value, depth, visited)
    local valueType = type(value)
    if value == nil then return 'nil' end
    if valueType == 'string' then
        return ('"%s"'):format(value)
    end
    if valueType == 'number' or valueType == 'boolean' then
        return tostring(value)
    end
    if valueType ~= 'table' then
        return ('<%s>'):format(valueType)
    end

    depth = depth or 0
    visited = visited or {}
    if visited[value] then
        return '<table:recursive>'
    end

    if depth >= 1 then
        local keys = {}
        local total = 0
        for key in pairs(value) do
            total = total + 1
            if #keys < 5 then
                keys[#keys + 1] = tostring(key)
            end
        end
        return ('<table keys=%s%s>'):format(table.concat(keys, ','), total > #keys and ',…' or '')
    end

    visited[value] = true
    local parts = {}
    local count = 0
    for key, entry in pairs(value) do
        count = count + 1
        if count > 5 then
            parts[#parts + 1] = '…'
            break
        end
        parts[#parts + 1] = ('%s=%s'):format(tostring(key), summarizeDebugValue(entry, depth + 1, visited))
    end
    visited[value] = nil

    return ('{%s}'):format(table.concat(parts, ', '))
end

local function debugModelResolution(origin, message, value)
    if not VRS.IsDebugEnabled('modelResolution') then return end

    local summary = summarizeDebugValue(value)
    local key = table.concat({
        tostring(origin or 'unknown'),
        tostring(message or 'log'),
        summary,
    }, '|')

    if modelDebugCache[key] then return end
    modelDebugCache[key] = true

    VRS.DebugLog('modelResolution', ('%s | origin=%s | value=%s'):format(message, origin or 'unknown', summary))
end

local function resolveModelReference(value, origin, path, visited)
    local valueType = type(value)
    if value == nil then return nil, nil end
    if valueType == 'string' or valueType == 'number' then
        return value, path or 'value'
    end

    if valueType ~= 'table' then
        debugModelResolution(origin, ('modelo inválido: tipo=%s'):format(valueType), value)
        return nil, nil
    end

    visited = visited or {}
    if visited[value] then
        debugModelResolution(origin, 'modelo inválido: tabela recursiva detectada', value)
        return nil, nil
    end

    visited[value] = true
    debugModelResolution(origin, 'joaat recebeu tipo=table; tentando normalizar campos conhecidos', value)

    local candidateFields = {
        'model',
        'modelName',
        'name',
        'prop',
        'platformModel',
        'hash',
        'modelHash',
    }

    for _, field in ipairs(candidateFields) do
        local candidate = rawget(value, field)
        if candidate ~= nil then
            local candidatePath = path and ('%s.%s'):format(path, field) or field
            debugModelResolution(origin, ('tentando usar field .%s'):format(field), candidate)

            local resolved, resolvedPath = resolveModelReference(candidate, origin, candidatePath, visited)
            if resolved ~= nil then
                debugModelResolution(origin, ('campo resolvido com sucesso: %s'):format(resolvedPath), resolved)
                visited[value] = nil
                return resolved, resolvedPath
            end
        end
    end

    visited[value] = nil
    debugModelResolution(origin, 'nenhum campo compatível encontrado para resolver model/hash', value)
    return nil, nil
end

--- Normaliza uma referência de modelo/hash antes de resolução
---@param model any
---@param origin string|nil
---@return string|number|nil, string|nil
function VRS.GetModelReference(model, origin)
    return resolveModelReference(model, origin or 'VRS.GetModelReference', 'value', {})
end

--- Resolve um model/hash para hash numérico
---@param model any
---@param origin string|nil
---@return number|nil
function VRS.ResolveModelHash(model, origin)
    local reference, resolvedPath = VRS.GetModelReference(model, origin or 'VRS.ResolveModelHash')
    if reference == nil then
        debugModelResolution(origin or 'VRS.ResolveModelHash', 'falha ao resolver model/hash; abortando com segurança', model)
        return nil
    end

    if type(reference) == 'number' then
        if type(model) == 'table' then
            debugModelResolution(origin or 'VRS.ResolveModelHash', ('hash numérico reaproveitado de %s'):format(resolvedPath or 'value'), reference)
        end
        return reference
    end

    if type(reference) ~= 'string' or reference == '' then
        debugModelResolution(origin or 'VRS.ResolveModelHash', 'referência de modelo inválida após normalização', reference)
        return nil
    end

    if type(model) == 'table' then
        debugModelResolution(origin or 'VRS.ResolveModelHash', ('convertendo string de %s via joaat'):format(resolvedPath or 'value'), reference)
    end

    return joaat(reference)
end

local function copyVec(value, fallback)
    local source = value or fallback
    if not source then return nil end
    return vec3(source.x or 0.0, source.y or 0.0, source.z or 0.0)
end

--- Retorna o profile configurado de um modelo de elevador
---@param liftOrModel table|string|number
---@return table
function VRS.GetLiftModelProfile(liftOrModel)
    local model = type(liftOrModel) == 'table' and (liftOrModel.model or liftOrModel.modelName or liftOrModel.platformModel or liftOrModel.name or liftOrModel.prop or liftOrModel.hash or liftOrModel.modelHash) or liftOrModel
    local defaults = VRS.DeepCopy(Config.Lift.ModelDefaults or {})
    local profiles = Config.Lift.Models or {}
    local normalizedModel = VRS.GetModelReference(model or liftOrModel, 'VRS.GetLiftModelProfile')

    if type(normalizedModel) == 'string' and profiles[normalizedModel] then
        for key, value in pairs(profiles[normalizedModel]) do
            defaults[key] = VRS.DeepCopy(value)
        end
        defaults.model = normalizedModel
        return defaults
    end

    local hash = VRS.ResolveModelHash(model or liftOrModel, 'VRS.GetLiftModelProfile')
    if hash then
        for profileName, profile in pairs(profiles) do
            local profileHash = VRS.ResolveModelHash(profile.model or profileName, ('VRS.GetLiftModelProfile.profile[%s]'):format(profileName))
            if profileHash == hash then
                for key, value in pairs(profile) do
                    defaults[key] = VRS.DeepCopy(value)
                end
                defaults.model = profile.model or profileName
                return defaults
            end
        end
    end

    defaults.model = type(normalizedModel) == 'string' and normalizedModel or defaults.model
    return defaults
end

--- Retorna métricas consolidadas do elevador a partir do entry + profile
---@param lift table
---@return table
function VRS.GetLiftMetrics(lift)
    local profile = VRS.GetLiftModelProfile(lift)
    return {
        profile = profile,
        minHeight = tonumber(lift and lift.minHeight or profile.minHeight) or Config.Lift.MinHeight or 0.0,
        maxHeight = tonumber(lift and lift.maxHeight or profile.maxHeight) or Config.Lift.MaxHeight or 2.1,
        vehicleOffset = copyVec(lift and lift.vehicleOffset, profile.vehicleOffset or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36)) or vec3(0.0, 0.0, Config.Lift.VehicleZOffset or 0.36),
        platformOffset = copyVec(lift and lift.platformOffset, profile.platformOffset or vec3(0.0, 0.0, 0.0)) or vec3(0.0, 0.0, 0.0),
        interactionOffset = copyVec(lift and lift.interactionOffset, profile.interactionOffset or Config.Lift.controlPanelOffset or vec3(1.9, 0.0, 0.0)) or vec3(1.9, 0.0, 0.0),
        length = tonumber(lift and lift.length or profile.length) or 5.0,
        width = tonumber(lift and lift.width or profile.width) or 2.5,
        family = lift and lift.family or profile.family or 'generic',
        sourceType = lift and lift.sourceType or profile.sourceType or 'spawned',
        useExistingEntity = lift and lift.useExistingEntity ~= nil and lift.useExistingEntity or profile.useExistingEntity or false,
        supportedClasses = lift and lift.supportedClasses or profile.supportedClasses,
        profileName = profile.model or 'default',
    }
end
