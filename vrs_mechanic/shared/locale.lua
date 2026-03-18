-- ============================================================
-- LOCALE LOADER
-- ============================================================

VRS = VRS or {}

local RESOURCE_NAME = GetCurrentResourceName()
local DEFAULT_LOCALE = 'pt-br'
local DEFAULT_FALLBACK = 'en'

lib.locale()

local function normalizeLocale(localeCode)
    if type(localeCode) ~= 'string' or localeCode == '' then
        return DEFAULT_LOCALE
    end

    localeCode = localeCode:lower():gsub('_', '-')

    if localeCode == 'pt' or localeCode:match('^pt%-') then
        return 'pt-br'
    end

    if localeCode == 'en-us' or localeCode == 'en-gb' or localeCode:match('^en%-') then
        return 'en'
    end

    return localeCode
end

local function dedupe(list)
    local seen = {}
    local result = {}

    for i = 1, #list do
        local value = list[i]
        if value and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end

    return result
end

local function readLocale(localeCode)
    local path = ('locales/%s.json'):format(localeCode)
    local content = LoadResourceFile(RESOURCE_NAME, path)
    if not content then return nil end

    local decoded = json.decode(content)
    if type(decoded) ~= 'table' then
        print(('[%s] Warning: invalid locale file "%s"'):format(RESOURCE_NAME, path))
        return nil
    end

    return decoded
end

local function deepMerge(base, override)
    local result = {}

    for key, value in pairs(base or {}) do
        if type(value) == 'table' then
            result[key] = deepMerge(value, {})
        else
            result[key] = value
        end
    end

    for key, value in pairs(override or {}) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = deepMerge(result[key], value)
        elseif type(value) == 'table' then
            result[key] = deepMerge({}, value)
        else
            result[key] = value
        end
    end

    return result
end

function VRS.LoadLocale()
    local configuredLocale = normalizeLocale((Config and Config.Locale) or GetConvar('ox:locale', GetConvar('locale', DEFAULT_LOCALE)))
    local defaultLocale = normalizeLocale((Config and Config.DefaultLocale) or DEFAULT_LOCALE)
    local fallbackLocale = normalizeLocale((Config and Config.FallbackLocale) or DEFAULT_FALLBACK)

    local candidates = dedupe({
        configuredLocale,
        defaultLocale,
        fallbackLocale,
    })

    local loaded = {}
    for i = 1, #candidates do
        local localeCode = candidates[i]
        loaded[localeCode] = readLocale(localeCode)
    end

    local resolvedLocale = configuredLocale
    if not loaded[resolvedLocale] then
        resolvedLocale = loaded[defaultLocale] and defaultLocale or fallbackLocale
    end

    local localeData = deepMerge(loaded[fallbackLocale] or {}, loaded[defaultLocale] or {})
    if resolvedLocale ~= defaultLocale then
        localeData = deepMerge(localeData, loaded[resolvedLocale] or {})
    end

    VRS.LocaleCode = resolvedLocale
    VRS.Locale = { UI = localeData }
    VRS.L = localeData

    return VRS.Locale
end

VRS.LoadLocale()
