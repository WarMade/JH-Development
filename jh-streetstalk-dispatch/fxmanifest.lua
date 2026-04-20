fx_version 'cerulean'
game 'gta5'

author 'Jhon Doe'
description 'Standalone Jurisdictional AI Police & Dispatch System'
version '1.0.0'

shared_scripts {
    'config.lua',
    'sh_bridge.lua' -- This is where we handle the framework bridge
}

client_scripts {
    'client/cl_main.lua',
    'client/dispatch.lua',
    'client/patrols.lua',
    'client/traffic.lua',
    'client/pull_over.lua',
    'client/warrants.lua'
}

server_scripts {
    'server/main.lua',
    'server/warrants.lua'
}

export 'GetClosestPatrol'
export 'AddZoneHeat'

server_export 'IncreaseHeat'
server_export 'AddZoneHeat'