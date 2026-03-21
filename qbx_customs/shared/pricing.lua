local sharedConfig = require 'config.shared'

local pricing = {}
local validPriceKeys = {
    cosmetic = true,
    repair = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [15] = true,
    [16] = true,
    [18] = true,
}

---@param mod 'cosmetic' | 'repair' | integer
---@param level? integer
---@return number
function pricing.get(mod, level)
    if not validPriceKeys[mod] then
        return 0
    end

    if mod == 'repair' then
        return 0
    end

    local price = sharedConfig.prices[mod]
    if type(price) == 'table' then
        local normalizedLevel = math.max(level or #price, 1)
        return price[normalizedLevel] or price[#price] or 0
    end

    return price or 0
end

---@param mod any
---@return boolean
function pricing.isSupportedMod(mod)
    return validPriceKeys[mod] == true
end

---@param bodyHealth number
---@return number
function pricing.getRepairPrice(bodyHealth)
    return math.max(0, math.ceil(1000 - math.max(bodyHealth or 0, 0)))
end

return pricing
