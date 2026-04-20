fx_version 'cerulean'
game 'gta5'
description 'JH-GangWars v8.5: The Definitive Version'
version '8.5.0'
author 'JH Scripts'
lua54 'yes'

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-input',
    'oxmysql'
}

shared_scripts {
    '@qb-core/shared/main.lua',
    'shared/config.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_loyalty.lua' -- Ensure this is loaded
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}
