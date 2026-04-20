fx_version 'cerulean'
game 'gta5'

description 'JH-Vibe: Immersive Ambient Interactions'
author 'Jhon Doe'

shared_scripts {
    'config.lua'
}

client_scripts {
    'animation.lua', -- Add this to ensure sequences load
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}