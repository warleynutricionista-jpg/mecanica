fx_version 'cerulean'
game 'gta5'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'OpenAI'
description 'qbx_customs rebuilt for Qbox compatibility'
repository 'https://github.com/Qbox-project/qbx_customs'
version '2.0.1'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'config/shared.lua',
    'config/client.lua',
    'shared/pricing.lua',
}

client_scripts {
    'client/session.lua',
    'client/services/feedback.lua',
    'client/services/access.lua',
    'client/services/vehicle.lua',
    'client/camera.lua',
    'client/catalog.lua',
    'client/menu.lua',
    'client/main.lua',
    'client/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/services/access.lua',
    'server/services/billing.lua',
    'server/services/persistence.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
    'carcols_gen9.meta',
    'carmodcols_gen9.meta',
}

data_file 'CARCOLS_GEN9_FILE' 'carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'carmodcols_gen9.meta'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
