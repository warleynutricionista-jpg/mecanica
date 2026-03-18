local Locales = {}

function RegisterLocale(locale, values)
    Locales[locale] = values
end

function L(key, ...)
    local locale = Config.Locale or 'en'
    local selected = Locales[locale] or Locales.en or {}
    local value = selected[key] or key

    if select('#', ...) > 0 then
        return value:format(...)
    end

    return value
end

function DebugLog(...)
    if not Config.Debug then return end
    print(('[BakiTelli_mechanic] %s'):format(table.concat({...}, ' ')))
end
