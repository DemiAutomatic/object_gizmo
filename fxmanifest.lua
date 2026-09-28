fx_version 'cerulean'
game 'gta5'
lua54 'yes'

version '3.0.0'

client_scripts {
	"client/gizmo.lua",
	'client/test.lua'
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

files {
	'locales/*.json',
	'client/dataview.lua',
}

server_script 'version.lua'

dependencies {
	'ox_lib'
}
