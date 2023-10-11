fx_version "adamant"
game "gta5"

shared_scripts {
	'config.lua',
}

client_script {
	"client/compass.lua"
}
client_script {
	"client/client.lua"
}

server_script{
	"server/server.lua"
}

ui_page "html/ui.html"

files {
	'html/svg/*.svg',
	'html/png/*.png',
	'html/star.png',
	'html/css/fonts/*.ttf',
	'html/css/fonts/*.woff',
	'html/css/fonts/*.woff2',
	"html/ui.html",
	"html/css/style.css",
	"html/js/script.js",
	'html/css/all.min.css',
	'html/js/all.min.js',
}