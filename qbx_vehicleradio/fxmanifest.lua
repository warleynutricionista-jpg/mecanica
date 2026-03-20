fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_vehicleradio'
description 'QBX vehicle radio with optional vrs_mechanic guards'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
}

client_script 'client.lua'

files {
    'config.json',
    'locales/*.json'
}
