fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vrs_mechanic'
author 'VRS Development'
description 'Sistema completo de mecânica para Qbox/QBX'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/locale.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'config/shared.lua',
    'config/lift.lua',
    'config/shops.lua',
    'config/items.lua',
    'config/services.lua',
    'config/panel.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/vehicle.lua',
    'shared/integration_reasons.lua',
    'shared/bridge.lua',
    'client/main.lua',
    'client/bridge.lua',
    'client/lift.lua',
    'client/lift_admin.lua',
    'client/vehicle_access.lua',
    'client/service_positions.lua',
    'client/duty.lua',
    'client/zones.lua',
    'client/target.lua',
    'client/diagnostics.lua',
    'client/repairs.lua',
    'client/upgrades.lua',
    'client/tablet.lua',
    'client/shop.lua',
    'client/animations.lua',
    'client/degradation.lua',
    'client/hub.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/shared.lua',
    'config/lift.lua',
    'config/shops.lua',
    'config/items.lua',
    'config/services.lua',
    'config/panel.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/vehicle.lua',
    'shared/integration_reasons.lua',
    'shared/bridge.lua',
    'server/main.lua',
    'server/bridge.lua',
    'server/services.lua',
    'server/panel_access.lua',
    'server/vehicles.lua',
    'server/repairs.lua',
    'server/inventory.lua',
    'server/workorders.lua',
    'server/billing.lua',
    'server/management.lua',
    'server/stashes.lua',
    'server/shop.lua',
    'server/lift_admin.lua',
    'server/lifts.lua',
    'server/upgrades_cb.lua',
    'server/logging.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.json',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

ox_lib 'locale'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
    'qbx_core',
}

provides {
    'qb-mechanicjob',
    'qbx_mechanicjob',
}
