fx_version 'cerulean'
game 'gta5'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'Jorn#0008'
description 'qbx_customs'
repository 'https://github.com/Qbox-project/qbx_customs'
version '1.1.0'

ox_lib 'locale'
shared_script '@ox_lib/init.lua'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'client/utils.lua',
    'client/session.lua',
    'client/actions.lua',
    'client/catalog.lua',
    'client/ui.lua',
    'client/main.lua',
    'client/zones.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'types.lua',
    'locales/*.json',
    'config/*.lua',
    'shared/**/*.lua',
    'client/**/*.lua',
    'carcols_gen9.meta',
    'carmodcols_gen9.meta',
}

data_file 'CARCOLS_GEN9_FILE' 'carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'carmodcols_gen9.meta'
