-- ============================================================
-- FUNÇÕES DE VEÍCULO COMPARTILHADAS
-- ============================================================

VRS = VRS or {}

--- Retorna a placa de um veículo
---@param vehicle number entity handle
---@return string|nil
function VRS.GetPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    if not DoesEntityExist(vehicle) then return nil end
    return string.gsub(GetVehicleNumberPlateText(vehicle), '^%s+', ''):gsub('%s+$', '')
end
