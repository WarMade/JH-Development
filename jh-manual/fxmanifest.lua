fx_version 'cerulean'
game 'gta5'

description 'JH-Manual: High-Performance Transmission & Physics'
version '1.0.0'

client_scripts {
    'config.lua',
    'client/cl_utils.lua',  -- Caching and Damage logic first
    'client/cl_input.lua',  -- Input mapping
    'client/cl_main.lua',   -- Core physics loop
    'client/cl_ui.lua'      -- UI updates
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

exports {
    'getCurrentGear',
    'setCurrentGear',
    'isClutchActive',
    'isEngineStalled',
    'isInNeutral',
    'setNeutral',
    'isLaunchControlActive',
    'isCurrentlyShifting',
}

lua54 'yes'

