extends Node

const BIG_MAP_SCENE = preload("res://map/maps/big_map.tscn")
const SMALL_MAP_SCENE = preload("res://map/maps/small_map.tscn")

var maps = {
	"BigMap": BIG_MAP_SCENE,
	"SmallMap": SMALL_MAP_SCENE,
}
var map = null
var color = Color()

func load_map(new_map, new_color):
	color = new_color
	map = maps[new_map].instance()
	map.modulate = color
	add_child(map)

func switch():
	var map_names = maps.keys()
	var map_index = map_names.find(Game.config.map)
	var new_map_name
	if map_index + 1 == len(map_names):
		new_map_name = map_names[0]
	else:
		new_map_name = map_names[map_index + 1]
	Game.config.map = new_map_name
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
