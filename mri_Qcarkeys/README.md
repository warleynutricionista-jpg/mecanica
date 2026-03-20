# mm_carkeys

Documentation to Install: https://master-mind-store.gitbook.io/dashboard/free-release/car-keys

## Novos exports/eventos públicos

### Server exports
- `exports.mri_Qcarkeys:GiveTemporaryKeys(source, vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:GivePermanentKeys(source, vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:RemoveKeys(source, vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:HasKeys(source, vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:RegisterSpawnedVehicle(source, vehicleEntityOrNetId, options)`
- `exports.mri_Qcarkeys:AssignKeysOnServiceSpawn(source, vehicleEntityOrNetId, options)`
- `exports.mri_Qcarkeys:AssignKeysOnAdminSpawn(source, vehicleEntityOrNetId, options)`

### Client exports
- `exports.mri_Qcarkeys:GiveTemporaryKeys(vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:GivePermanentKeys(vehicleOrPlate, metadata)`
- `exports.mri_Qcarkeys:RemoveKeys(vehicleOrPlate)`
- `exports.mri_Qcarkeys:HasKeys(vehicleOrPlate)`
- `exports.mri_Qcarkeys:RegisterSpawnedVehicle(vehicleEntity, options)`
- `exports.mri_Qcarkeys:AssignKeysOnServiceSpawn(vehicleEntity, options)`
- `exports.mri_Qcarkeys:AssignKeysOnAdminSpawn(vehicleEntity, options)`

## Exemplo de integração

### Spawn de veículo de serviço
```lua
local ok, netId = lib.callback.await('myjob:server:spawnServiceVehicle', false, model)
if ok and GetResourceState('mri_Qcarkeys') == 'started' then
    exports.mri_Qcarkeys:AssignKeysOnServiceSpawn(cache.serverId, netId, {
        reason = 'myjob_service_spawn',
        temporary = true,
    })
end
```

### Spawn administrativo
```lua
local netId, veh = qbx.spawnVehicle({
    model = model,
    spawnSource = GetPlayerPed(source),
    warp = true,
})

if GetResourceState('mri_Qcarkeys') == 'started' then
    exports.mri_Qcarkeys:AssignKeysOnAdminSpawn(source, veh, {
        reason = 'my_admin_menu_spawn',
        temporary = true,
    })
end
```
