# AutoLoaded Singleton

extends Node

const VERSION = "Dev Build"

var is_playing = false
var config = {
	"peer_name": "",
	"ip": "",
	"is_open_to_lan": true,
	"using_small_map": false,
	"max_health": 3,
	"ball_count": 10,
}

func _enter_tree():
	load_config()

func load_config():
	var file = File.new()
	if file.file_exists("user://config.json"):
		file.open("user://config.json", File.READ)
		var config_from_file = parse_json(file.get_line())
		for key in config_from_file:
			Game.config[key] = config_from_file[key]
		file.close()

func save_config():
	var file = File.new()
	file.open("user://config.json", File.WRITE)
	file.store_line(to_json(Game.config))
	file.close()
