fx_version 'cerulean'
game 'gta5'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'OpenAI'
description 'qbx_customs rebuilt for Qbox compatibility'
repository 'https://github.com/Qbox-project/qbx_customs'
version '2.0.0'

ox_lib 'locale'
shared_script '@ox_lib/init.lua'

shared_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'config/shared.lua',
    'config/client.lua',
    'shared/*.lua',
}

client_scripts {
    'client/services/*.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/services/*.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
    'config/*.lua',
    'shared/*.lua',
    'client/*.lua',
    'client/services/*.lua',
    'server/*.lua',
    'server/services/*.lua',
    'types.lua',
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
