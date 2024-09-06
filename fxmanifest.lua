fx_version 'cerulean'
games { 'gta5' }

author 'Musiker15 - MSK Scripts'
name 'msk_enginetoggle'
description 'EngineToggle for Vehicles'
version '4.2.1'

lua54 'yes'

shared_script {
	'@ox_lib/init.lua',
    'config.lua',
	'translation.lua'
}

client_scripts {
	'client/**/*.*'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/**/*.*'
}

dependencies {
	'oxmysql',
	'ox_lib',
}