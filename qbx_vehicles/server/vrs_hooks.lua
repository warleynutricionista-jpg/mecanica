QbxVehiclesVrsHooks = QbxVehiclesVrsHooks or {}

function QbxVehiclesVrsHooks.IsActive()
    return GetResourceState('vrs_mechanic') == 'started'
end

function QbxVehiclesVrsHooks.AttachPersistence(props)
    if not QbxVehiclesVrsHooks.IsActive() or type(props) ~= 'table' or not props.plate then
        return props
    end

    local ok, persistence = pcall(function()
        return exports.vrs_mechanic:GetVehiclePersistenceData(props.plate)
    end)

    if ok and persistence then
        props.vrsMechanic = persistence
    end

    return props
end

function QbxVehiclesVrsHooks.SeedPersistence(props)
    if not QbxVehiclesVrsHooks.IsActive() or type(props) ~= 'table' or not props.plate then
        return
    end

    local persisted = props.vrsMechanic
    if not persisted or type(persisted.status) ~= 'table' then
        return
    end

    pcall(function()
        exports.vrs_mechanic:SeedVehicleStatus(props.plate, persisted.status)
    end)
end

function QbxVehiclesVrsHooks.CleanupPersistence(plates)
    if not QbxVehiclesVrsHooks.IsActive() or type(plates) ~= 'table' then
        return
    end

    for i = 1, #plates do
        pcall(function()
            exports.vrs_mechanic:RemoveVehicleStatus(plates[i])
        end)
    end
end

function QbxVehiclesVrsHooks.ValidateStorage(vehicle, options)
    if not QbxVehiclesVrsHooks.IsActive() then
        return true
    end

    local ok, canStore, reason = pcall(function()
        return exports.vrs_mechanic:CanStoreVehicle(vehicle, options)
    end)

    if not ok then
        return true
    end

    return canStore ~= false, reason
end
