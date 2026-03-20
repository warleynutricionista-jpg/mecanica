-- ============================================================
-- UTILITÁRIOS COMPARTILHADOS
-- ============================================================

VRS = VRS or {}

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

--- Resolve um model/hash para hash numérico
---@param model string|number|nil
---@return number|nil
function VRS.ResolveModelHash(model)
    if not model then return nil end
    if type(model) == 'number' then return model end
    return joaat(model)
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
    local model = type(liftOrModel) == 'table' and (liftOrModel.model or liftOrModel.modelName or liftOrModel.platformModel) or liftOrModel
    local defaults = VRS.DeepCopy(Config.Lift.ModelDefaults or {})
    local profiles = Config.Lift.Models or {}

    if type(model) == 'string' and profiles[model] then
        for key, value in pairs(profiles[model]) do
            defaults[key] = VRS.DeepCopy(value)
        end
        defaults.model = model
        return defaults
    end

    local hash = VRS.ResolveModelHash(model)
    if hash then
        for profileName, profile in pairs(profiles) do
            local profileHash = VRS.ResolveModelHash(profile.model or profileName)
            if profileHash == hash then
                for key, value in pairs(profile) do
                    defaults[key] = VRS.DeepCopy(value)
                end
                defaults.model = profile.model or profileName
                return defaults
            end
        end
    end

    defaults.model = type(model) == 'string' and model or defaults.model
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
