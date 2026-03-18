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

