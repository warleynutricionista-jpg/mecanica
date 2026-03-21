fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'BryaN / Refactor by OpenAI'
description 'Premium paint booth workflow for FiveM with Qbox/QBCore, ox_lib and ox_target support'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/utils.lua',
    'client/effects.lua',
    'client/paint.lua',
    'client/ui.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
}
