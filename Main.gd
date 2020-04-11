extends Node2D

signal new_player(health, color)
export (PackedScene) var Player
export (PackedScene) var Ball
export var total_health = 4
export var max_players = 8
var players = []
var pads_to_players = {}
var used_colors = []
var player_spawns = []
var ball_spawns = []
var zoom_threshold = 500
var zoom_acceleration = 0.05

func _ready():
	OS.min_window_size = Vector2(1280, 720)
	player_spawns = $TestMap/PlayerSpawns.get_children()
	ball_spawns = $TestMap/BallSpawns.get_children()
	$Camera2D.position = $TestMap/DefCamPos.position
	for spawn in ball_spawns:
		var ball = Ball.instance()
		ball.position = spawn.position
		add_child(ball)
	randomize()
	var map_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	$TestMap.modulate = map_color
	used_colors.append(map_color)

func new_player(id):
	pads_to_players[id] = pads_to_players.size()
	var new_player = Player.instance()
	new_player.player_number = pads_to_players[id]
	new_player.total_health = total_health
	randomize()
	var new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	while used_colors.has(new_color) and used_colors.size() < 17:
		randomize()
		new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	used_colors.append(new_color)
	new_player.modulate = new_color
	emit_signal("new_player", total_health, new_color)
	new_player.spawn_position = player_spawns[pads_to_players[id]].position
	new_player.position = new_player.spawn_position
	new_player.pad_id = id
	new_player.connect("give_point", $CanvasLayer/HUD, "_on_give_point")
	new_player.connect("health", $CanvasLayer/HUD, "_on_player_health")
	players.append(new_player)
	add_child(new_player)

func _process(_delta):
	if pads_to_players.size() < max_players:
		if Input.is_key_pressed(KEY_ENTER) and not pads_to_players.has(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and not pads_to_players.has(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 11) and not pads_to_players.has(c):
					new_player(c)

	if players.size() > 0:
		var avg_x = 0
		var avg_y = 0
		for player in players:
			avg_x += player.position.x
			avg_y += player.position.y
		avg_x /= players.size()
		avg_y /= players.size()
		$Camera2D.position = Vector2(avg_x, avg_y)
	
	if players.size() > 1:
		var max_x = players[0].position.x
		var min_x = players[0].position.x
		var max_y = players[0].position.y
		var min_y = players[0].position.y
		for player in players:
			if player.position.x > max_x:
				max_x = player.position.x
			if player.position.x < min_x:
				min_x = player.position.x
			if player.position.y > max_y:
				max_y = player.position.y
			if player.position.y < min_y:
				min_y = player.position.y
		var new_zoom = Vector2.ZERO
		var new_zoom_x = (abs(max_x - min_x) + zoom_threshold) / OS.window_size.x
		var new_zoom_y = (abs(max_y - min_y) + zoom_threshold) / OS.window_size.y
		new_zoom.x = new_zoom_x if new_zoom_x > new_zoom_y else new_zoom_y
		new_zoom.y = new_zoom_x if new_zoom_x > new_zoom_y else new_zoom_y
		new_zoom = Vector2(1, 1) if new_zoom < Vector2(1, 1) else new_zoom
		$Camera2D.zoom = $Camera2D.zoom.linear_interpolate(new_zoom, zoom_acceleration)

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ESCAPE:
			return get_tree().reload_current_scene()
