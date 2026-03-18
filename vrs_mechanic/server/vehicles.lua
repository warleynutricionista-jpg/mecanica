-- ============================================================
-- VRS_MECHANIC - VEHICLE STATUS PERSISTENCE (SERVER)
-- ============================================================

local vehicleStatusCache = {}

--- Carrega status do veículo do banco de dados
---@param plate string
---@return table|nil
local function loadStatusFromDB(plate)
    local result = MySQL.query.await(
        'SELECT status FROM vrs_mechanic_vehicle_status WHERE plate = ?',
        { plate }
    )
    if result and result[1] and result[1].status then
        return json.decode(result[1].status)
    end
    return nil
end

--- Salva status do veículo no banco de dados
---@param plate string
---@param status table
local function saveStatusToDB(plate, status)
    MySQL.insert.await(
        [[INSERT INTO vrs_mechanic_vehicle_status (plate, status, updated_at)
          VALUES (?, ?, NOW())
          ON DUPLICATE KEY UPDATE status = VALUES(status), updated_at = NOW()]],
        { plate, json.encode(status) }
    )
end

--- Obtém status do veículo (cache ou DB)
---@param plate string
---@return table
local function getVehicleStatus(plate)
    if vehicleStatusCache[plate] then
        return vehicleStatusCache[plate]
    end

    local dbStatus = loadStatusFromDB(plate)
    if dbStatus then
        vehicleStatusCache[plate] = dbStatus
        return dbStatus
    end

    -- Status padrão para veículo novo
    local defaultStatus = VRS.GetDefaultStatus()
    vehicleStatusCache[plate] = defaultStatus
    return defaultStatus
end

-- ============================================================
-- CALLBACKS
-- ============================================================

-- Callback: obter status completo do veículo
lib.callback.register('vrs_mechanic:server:getVehicleStatus', function(source, plate)
    if not plate or plate == '' then return nil end
    return getVehicleStatus(plate)
end)

-- Callback: obter status de uma parte específica
lib.callback.register('vrs_mechanic:server:getPartStatus', function(source, plate, part)
    if not plate or not part then return nil end
    local status = getVehicleStatus(plate)
    return status[part]
end)

-- ============================================================
-- EVENTOS
-- ============================================================

-- Evento: configurar status do veículo (ao entrar)
RegisterNetEvent('vrs_mechanic:server:setupVehicleStatus', function(plate, engineHealth, bodyHealth)
    local src = source
    if not plate or plate == '' then return end

    local status = getVehicleStatus(plate)

    -- Se é primeira vez, sincronizar com valores nativos do GTA
    if not vehicleStatusCache[plate] and not loadStatusFromDB(plate) then
        status.engine = engineHealth or Config.MaxStatus.engine
        status.body = bodyHealth or Config.MaxStatus.body
    end

    vehicleStatusCache[plate] = status

    -- Broadcast para todos os clientes
    TriggerClientEvent('vrs_mechanic:client:syncVehicleStatus', -1, plate, status)
end)

-- Evento: atualizar uma parte específica
RegisterNetEvent('vrs_mechanic:server:updatePart', function(plate, part, value)
    local src = source
    if not plate or not part or not value then return end
    if not VRS.IsValidPart(part) then return end

    local status = getVehicleStatus(plate)
    local max = Config.MaxStatus[part] or 100
    status[part] = VRS.Clamp(value, 0, max)
    vehicleStatusCache[plate] = status

    TriggerClientEvent('vrs_mechanic:client:syncVehicleStatus', -1, plate, status)
end)

-- Evento: atualizar múltiplas partes
RegisterNetEvent('vrs_mechanic:server:updateMultipleParts', function(plate, updates)
    local src = source
    if not plate or not updates then return end

    local status = getVehicleStatus(plate)
    for part, value in pairs(updates) do
        if VRS.IsValidPart(part) then
            local max = Config.MaxStatus[part] or 100
            status[part] = VRS.Clamp(value, 0, max)
        end
    end
    vehicleStatusCache[plate] = status

    TriggerClientEvent('vrs_mechanic:client:syncVehicleStatus', -1, plate, status)
end)

-- Evento: salvar status persistentemente (chamado ao sair do veículo / periodicamente)
RegisterNetEvent('vrs_mechanic:server:saveVehicleStatus', function(plate)
    local src = source
    if not plate or not vehicleStatusCache[plate] then return end
    saveStatusToDB(plate, vehicleStatusCache[plate])
end)

-- ============================================================
-- PERSISTÊNCIA PERIÓDICA
-- ============================================================

-- Salva todos os status em cache a cada 5 minutos
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutos
        local count = 0
        for plate, status in pairs(vehicleStatusCache) do
            saveStatusToDB(plate, status)
            count = count + 1
        end
        if count > 0 then
            print(('[vrs_mechanic] ^3Salvos %d status de veículos^0'):format(count))
        end
    end
end)

-- Salvar tudo ao parar o resource
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for plate, status in pairs(vehicleStatusCache) do
        saveStatusToDB(plate, status)
    end
    print('[vrs_mechanic] ^3Todos os status salvos ao parar resource^0')
end)

-- ============================================================
-- EXPORTS
-- ============================================================

exports('GetVehicleStatus', function(plate)
    return getVehicleStatus(plate)
end)

exports('SetVehiclePartStatus', function(plate, part, value)
    if not plate or not part or not value then return false end
    if not VRS.IsValidPart(part) then return false end

    local status = getVehicleStatus(plate)
    local max = Config.MaxStatus[part] or 100
    status[part] = VRS.Clamp(value, 0, max)
    vehicleStatusCache[plate] = status

    TriggerClientEvent('vrs_mechanic:client:syncVehicleStatus', -1, plate, status)
    return true
end)
