fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'EJJ_04'

client_scripts {
    'client/bridge.lua',
    'client/functions.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
    'server/logs.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

files {
    'locales/*.json'
}
