fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
game 'gta5'
lua54 'yes'

name 'object_gizmo'
author 'DemiAutomatic'
description 'Move and rotate entities with a 3D gizmo'
version '3.1.0'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
	'client/main.lua',
	'client/test.lua'
}

server_script 'version.lua'

ui_page 'web/dist/index.html'

files {
	'locales/*.json',
	'client/modules/*.lua',
	'web/dist/index.html',
	'web/dist/**/*',
}

dependencies {
	'ox_lib'
}
