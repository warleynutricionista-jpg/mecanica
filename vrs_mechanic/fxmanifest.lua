fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vrs_mechanic'
author 'VRS Development'
description 'Sistema completo de mecânica para Qbox/QBX'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'config/shared.lua',
    'config/shops.lua',
    'config/items.lua',
    'shared/*.lua',
    'client/main.lua',
    'client/zones.lua',
    'client/target.lua',
    'client/diagnostics.lua',
    'client/repairs.lua',
    'client/upgrades.lua',
    'client/duty.lua',
    'client/tablet.lua',
    'client/animations.lua',
    'client/degradation.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/shared.lua',
    'config/shops.lua',
    'config/items.lua',
    'shared/*.lua',
    'server/main.lua',
    'server/vehicles.lua',
    'server/repairs.lua',
    'server/inventory.lua',
    'server/workorders.lua',
    'server/billing.lua',
    'server/management.lua',
    'server/stashes.lua',
    'server/upgrades_cb.lua',
    'server/logging.lua',
}

ui_page 'web/index.html'

files {
    'locales/*.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

ox_libs {
    'locale',
}

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
