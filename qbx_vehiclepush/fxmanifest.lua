fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_vehiclepush'
description 'QBX vehicle push with optional vrs_mechanic guards'

shared_scripts {
    '@ox_lib/init.lua',
}

client_script 'client.lua'
server_script 'server.lua'

files {
    'config.json'
}
