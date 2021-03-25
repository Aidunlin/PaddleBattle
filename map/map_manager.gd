extends Node

const BIG_MAP_SCENE = preload("res://map/bigmap.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")

var map = null
var color = Color()

func load_map(is_small_map, new_color):
	color = new_color
	if is_small_map:
		map = SMALL_MAP_SCENE.instance()
	else:
		map = BIG_MAP_SCENE.instance()
	map.modulate = color
	add_child(map)

func get_camera_spawn():
	return map.get_node("CameraSpawn").position

func get_paddle_spawns():
	return map.get_node("PaddleSpawns").get_children()

func get_ball_spawns():
	return map.get_node("BallSpawns").get_children()

func reset():
	if map:
		map.queue_free()
