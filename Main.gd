extends Node2D

export var total_health = 4
export var max_players = 8

onready var camera = get_node("Camera2D")
onready var players = get_node("Players")
onready var balls = get_node("Balls")
onready var bars = get_node("UILayer/HUD/Bars")
onready var player_spawns = get_node("TestMap/PlayerSpawns").get_children()
onready var ball_spawns = get_node("TestMap/BallSpawns").get_children()

var player_db = []
var used_colors = []
var zoom_threshold = 500
var zoom_acceleration = 0.05

func _ready():
	OS.min_window_size = Vector2(1280, 720)
	camera.position = get_node("TestMap/DefCamPos").position
	for spawn in ball_spawns:
		var ball = load("res://Ball.tscn").instance()
		ball.position = spawn.position
		balls.add_child(ball)
	randomize()
	var map_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	used_colors.append(map_color)
	get_node("TestMap").modulate = map_color

# Create new player
func new_player(id):
	var player_number = player_db.size()
	var new_player = load("res://Player.tscn").instance()
	new_player.pad_id = id
	player_db.append({"pad": id})
	new_player.player_number = player_number
	new_player.total_health = total_health
	player_db[player_number]["health"] = total_health
	randomize()
	var new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	while used_colors.has(new_color):
		randomize()
		new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	used_colors.append(new_color)
	new_player.modulate = new_color
	add_player_to_hud(player_number, total_health, new_color)
	player_db[player_number]["color"] = new_color
	new_player.spawn_position = player_spawns[player_number].position
	new_player.spawn_rotation = player_spawns[player_number].rotation
	new_player.connect("hit", self, "on_player_hit")
	player_db[player_number]["node"] = new_player
	players.add_child(new_player)
	players.move_child(new_player, 0)

# Manage player health
func on_player_hit(player_num):
	var player = player_db[player_num]
	if player["health"] <= 1:
		player["node"].reset()
		player["health"] = total_health
	else:
		player["node"].damage()
		player["health"] -= 1
	var hp_bits = player["hud"].get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(0.2,0.2,0.2,0.2)
		if player["health"] > i:
			hp_bits[i].modulate = Color(1,1,1,1)

# Add player HUD
func add_player_to_hud(player, hp, col):
	var new_bar = HBoxContainer.new()
	new_bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	new_bar.modulate = col
	new_bar.alignment = BoxContainer.ALIGN_CENTER
	var bars_wrap = VBoxContainer.new()
	var hp_bar = HBoxContainer.new()
	var hp_texture = TextureRect.new()
	hp_texture.texture = load("res://img/hp-label.png")
	hp_bar.add_child(hp_texture)
	var hp_bits = HBoxContainer.new()
	hp_bits.set("custom_constants/separation", -18)
	for _x in range(hp):
		var hp_bit = TextureRect.new()
		hp_bit.texture = load("res://img/hp-bit.png")
		hp_bits.add_child(hp_bit)
	hp_bar.add_child(hp_bits)
	bars_wrap.add_child(hp_bar)
	new_bar.add_child(bars_wrap)
	bars.add_child(new_bar)
	bars.columns = clamp(bars.get_children().size(), 0, 4)
	player_db[player]["hud"] = hp_bits

# Checks if a pad is already used
func is_new_pad(id):
	for p in player_db:
		if p["pad"] == id:
			return false
	return true

func _process(_delta):
	# Create player if sensed input
	if player_db.size() < max_players:
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, JOY_START) and is_new_pad(c):
					new_player(c)
	if Input.is_key_pressed(KEY_ESCAPE):
		return get_tree().reload_current_scene()
	
	# Center camera to average player position
	if players.get_child_count() > 0:
		var avg_x = 0
		var avg_y = 0
		for player in players.get_children():
			avg_x += player.position.x
			avg_y += player.position.y
		avg_x /= players.get_child_count()
		avg_y /= players.get_child_count()
		camera.position = Vector2(avg_x, avg_y)
	
	# Zoom camera to always view all players
	if players.get_child_count() > 1:
		var max_x = players.get_children()[0].position.x
		var min_x = players.get_children()[0].position.x
		var max_y = players.get_children()[0].position.y
		var min_y = players.get_children()[0].position.y
		for player in players.get_children():
			max_x = player.position.x if player.position.x > max_x else max_x
			min_x = player.position.x if player.position.x < min_x else min_x
			max_y = player.position.y if player.position.y > max_y else max_y
			min_y = player.position.y if player.position.y < min_y else min_y
		var new_zoom = Vector2.ZERO
		var new_zoom_x = (abs(max_x - min_x) + zoom_threshold) / OS.window_size.x
		var new_zoom_y = (abs(max_y - min_y) + zoom_threshold) / OS.window_size.y
		new_zoom.x = new_zoom_x if new_zoom_x > new_zoom_y else new_zoom_y
		new_zoom.y = new_zoom_x if new_zoom_x > new_zoom_y else new_zoom_y
		new_zoom = Vector2(1, 1) if new_zoom < Vector2(1, 1) else new_zoom
		camera.zoom = camera.zoom.linear_interpolate(new_zoom, zoom_acceleration)
