local sharedConfig = require 'config.shared'

local pricing = {}

local supported = {
    cosmetic = true,
    repair = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [15] = true,
    [16] = true,
    [18] = true,
}

local function normalizeLevel(level)
    local numericLevel = math.floor(tonumber(level) or 1)
    if numericLevel < 1 then
        return 1
    end

    return numericLevel
end

function pricing.isSupported(key)
    return supported[key] == true
end

function pricing.get(key, level, context)
    if not pricing.isSupported(key) then
        return 0
    end

    if key == 'repair' then
        local bodyHealth = context and context.bodyHealth or 1000.0
        local repairConfig = sharedConfig.prices.repair
        local missing = math.max(0, 1000.0 - math.max(tonumber(bodyHealth) or 0.0, 0.0))
        local amount = math.ceil(missing * (repairConfig.multiplier or 1.0))
        amount = math.max(repairConfig.minimum or 0, amount)
        if repairConfig.maximum then
            amount = math.min(repairConfig.maximum, amount)
        end
        if missing <= 0 then
            return 0
        end

        return amount
    end

    local price = sharedConfig.prices[key]
    if type(price) == 'table' then
        local index = normalizeLevel(level)
        return price[index] or price[#price] or 0
    end

    return tonumber(price) or 0
end

return pricing
