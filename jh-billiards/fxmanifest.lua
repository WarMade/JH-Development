fx_version 'cerulean'
game 'gta5'

author 'JH Scripts'
description 'JH Billiards - Advanced Pool Minigame with Betting & Leaderboards'
version '1.0.0'

-- This enables modern Lua features (backticks, math improvements, etc.)
lua54 'yes'

-- Client Scripts
client_scripts {
    'client/main.lua',
    -- If you have extra files for physics or UI, add them here
}

-- Server Scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Required for the Leaderboard database functions
    'server/main.lua'
}

-- Target and Framework Dependencies
dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',  -- For the Leaderboard display
    'qb-input' -- For the Betting dialog
}

-- Define the metadata for the pool table props to ensure they network correctly
data_file 'DLC_ITYP_REQUEST' 'prop_pooltable_02'