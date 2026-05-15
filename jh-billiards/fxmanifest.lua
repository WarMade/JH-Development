fx_version 'cerulean'
game 'gta5'

author 'SwisserAI'
description 'JH Billiards - Advanced Pool Minigame with Betting & Leaderboards. Generated with SwisserAI - https://ai.swisser.dev'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-input'
}

data_file 'DLC_ITYP_REQUEST' 'prop_pooltable_02'
