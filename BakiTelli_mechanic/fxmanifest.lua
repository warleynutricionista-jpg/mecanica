fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'BakiTelli Mechanic (Qbox Rewrite)'
author 'Senior FiveM Rewrite by Codex'
description 'Secure and production-ready mechanic workflow for Qbox'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/*.lua',
    'locales/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql',
    'qbx_core'
}
