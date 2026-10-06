fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'takeperso'
description 'Persönliches Menü (F5): Personalausweis, Führerschein, Waffenschein ansehen, zeigen und geben'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*'
}
