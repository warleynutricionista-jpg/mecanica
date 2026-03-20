-- ============================================================
-- VRS_MECHANIC - BRIDGE COMPARTILHADA DE INTEGRAÇÃO
-- ============================================================

VRS = VRS or {}

VRS.PartAliases = VRS.PartAliases or {
    fuel = 'fuel_tank',
    fueltank = 'fuel_tank',
    petrol = 'fuel_tank',
    petroltank = 'fuel_tank',
    enginehealth = 'engine',
    bodyhealth = 'body',
}

---@param module string|nil
---@return boolean
function VRS.IsIntegrationDebugEnabled(module)
    local integration = Config.VehicleIntegration or {}
    local modules = integration.DebugModules or {}

    if module and modules[module] ~= nil then
        return modules[module] == true
    end

    return integration.DebugVehicleIntegration == true or VRS.IsDebugEnabled('bridge')
end

---@param module string
---@param message string
function VRS.IntegrationLog(module, message)
    if not VRS.IsIntegrationDebugEnabled(module) then return end
    print(('[vrs_mechanic][integration][%s] %s'):format(module or 'general', message or ''))
end

---@return boolean
function VRS.IsIntegrationEnabled()
    return Config.EnableVrsMechanicIntegration ~= false
end

---@param part string|nil
---@return string|nil
function VRS.NormalizePartName(part)
    if type(part) ~= 'string' then return part end

    local normalized = part:lower():gsub('[%s%-_]', '')
    return VRS.PartAliases[normalized] or part
end

---@param status table|nil
---@return boolean
function VRS.HasCriticalMechanicalFailure(status)
    if type(status) ~= 'table' then return false end

    local integration = Config.VehicleIntegration or {}
    local engineThreshold = integration.CriticalEngineThreshold or 150.0
    local batteryThreshold = integration.CriticalBatteryThreshold or 5.0

    local engine = tonumber(status.engine or Config.MaxStatus.engine or 1000.0) or 0.0
    local battery = tonumber(status.battery or Config.MaxStatus.battery or 100.0) or 0.0

    return engine <= engineThreshold or battery <= batteryThreshold
end

---@param status table|nil
---@return table
function VRS.BuildMechanicalSummary(status)
    local data = type(status) == 'table' and VRS.DeepCopy(status) or nil
    return {
        status = data,
        disabled = VRS.HasCriticalMechanicalFailure(data),
        engineHealth = data and data.engine or nil,
        bodyHealth = data and data.body or nil,
        batteryHealth = data and data.battery or nil,
    }
end
