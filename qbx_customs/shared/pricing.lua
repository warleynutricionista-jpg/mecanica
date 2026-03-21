local sharedConfig = require 'config.shared'

local pricing = {}

---@param mod 'cosmetic' | 'repair' | integer
---@param level? integer
---@return number
function pricing.get(mod, level)
    if mod == 'repair' then
        return 0
    end

    local price = sharedConfig.prices[mod]
    if type(price) == 'table' then
        if not level then
            return price[#price] or 0
        end

        return price[level] or price[#price] or 0
    end

    return price or 0
end

---@param bodyHealth number
---@return number
function pricing.getRepairPrice(bodyHealth)
    return math.max(0, math.ceil(1000 - bodyHealth))
end

return pricing
