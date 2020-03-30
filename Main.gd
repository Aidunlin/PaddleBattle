extends Node2D

signal new_player(health, color)
export (PackedScene) var Player
export (PackedScene) var Ball
export var total_health = 4
var pads_to_players = {}
var used_colors = []
var player_spawns = []
var ball_spawns = []

func _ready():
	ball_spawns = $TestMap/BallSpawns.get_children()
	for spawn in ball_spawns:
		var ball = Ball.instance()
		ball.position = spawn.position
		add_child(ball)
	randomize()
	var map_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	$TestMap.modulate = map_color
	used_colors.append(map_color)
	player_spawns = $TestMap/PlayerSpawns.get_children()

func _process(_delta):
	for c in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(c, 11) and not pads_to_players.has(c) and pads_to_players.size() < 8:
			pads_to_players[c] = pads_to_players.size()
			var new_player = Player.instance()
			new_player.player_number = pads_to_players[c]
			new_player.total_health = total_health
			randomize()
			var new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
			while used_colors.has(new_color) and used_colors.size() < 17:
				randomize()
				new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
			used_colors.append(new_color)
			new_player.modulate = new_color
			emit_signal("new_player", total_health, new_color)
			new_player.spawn_position = player_spawns[pads_to_players[c]].position
			new_player.position = new_player.spawn_position
			new_player.pad_id = c
			new_player.connect("give_point", $CanvasLayer/HUD, "_on_give_point")
			new_player.connect("health", $CanvasLayer/HUD, "_on_player_health")
			add_child(new_player)

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ESCAPE:
			return get_tree().reload_current_scene()
