extends Node

const MAPS = {
	"BigMap": preload("res://maps/big_map.tscn"),
	"SmallMap": preload("res://maps/small_map.tscn"),
}

var map = null
var color = Color()

func load_map(new_map, new_color):
	color = new_color
	map = MAPS[new_map].instance()
	map.modulate = color
	add_child(map)

func switch():
	var map_names = MAPS.keys()
	var map_index = map_names.find(Game.map)
	var new_index = 0
	if map_index + 1 != len(map_names):
		new_index = map_index + 1
	var new_map_name = map_names[new_index]
	Game.map = new_map_name
	return new_map_name

func get_camera_spawn():
	return map.get_node("CameraSpawn").position

func get_paddle_spawns():
	return map.get_node("PaddleSpawns").get_children()

func get_ball_spawns():
	return map.get_node("BallSpawns").get_children()

func reset():
	if map:
		map.queue_free()
		map = null
