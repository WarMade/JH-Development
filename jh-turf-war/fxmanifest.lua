fx_version 'cerulean'
game 'gta5'

author 'Jhon Doe'
description 'Dynamic Turf War & Rivalry System'

shared_scripts {
    'config.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/cl_main.lua',
    'client/cl_map.lua'
}

server_scripts {
    'server/sv_main.lua'
}

dependencies {
    'PolyZone',
    'qb-core'
}