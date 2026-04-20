fx_version 'cerulean'
game 'gta5'

author 'Jhon doe'
description 'Full server-side persistence - last 5 driver vehicles (QBCore + citizenid)'
version '2.1.0'

dependencies {
    'qb-core',
    'oxmysql'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

lua54 'yes'
files {
    'sql.sql'
}