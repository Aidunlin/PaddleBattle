extends Node2D

onready var main_menu = "UILayer/Menu/Main/"
onready var message = get_node("UILayer/Message")
onready var camera = get_node("Game/Camera2D")
onready var players = get_node("Game/Players")
onready var bars = get_node("UILayer/HUD/Bars")
onready var player_spawns = get_node("Game/TestMap/PlayerSpawns")

var playing = false
var started = false
var max_hp = 3
var max_players = 4
var max_balls = 10
var player_db = []
var used_colors = []
var zoom_margin = 500
var zoom_accel = 0.05

func _ready():
	get_node(main_menu + "Play").connect("pressed", self, "load_game")
	get_node(main_menu + "Quit").connect("pressed", get_tree(), "quit")
	get_node(main_menu + "Health/Inc").connect("pressed", self, "crement", ["hp", 1])
	get_node(main_menu + "Health/Dec").connect("pressed", self, "crement", ["hp", -1])
	get_node(main_menu + "Players/Inc").connect("pressed", self, "crement", ["players", 1])
	get_node(main_menu + "Players/Dec").connect("pressed", self, "crement", ["players", -1])
	get_node(main_menu + "Balls/Inc").connect("pressed", self, "crement", ["balls", 1])
	get_node(main_menu + "Balls/Dec").connect("pressed", self, "crement", ["balls", -1])
	get_node("Game/ResetTimer").connect("timeout", self, "unload_game")
	
	var save_data = File.new()
	if save_data.file_exists("user://save.txt"):
		save_data.open("user://save.txt", File.READ)
		max_hp = int(save_data.get_line())
		max_players = int(save_data.get_line())
		max_balls = int(save_data.get_line())
		save_data.close()
	update_option_nodes()
	
	randomize()
	var map_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	used_colors.append(map_color)
	get_node("Game/TestMap").modulate = map_color
	camera.position = get_node("Game/TestMap/DefCamPos").position
	update_balls()

func update_option_nodes():
	get_node(main_menu + "Health/HealthNum").text = str(max_hp)
	get_node(main_menu + "Players/PlayerNum").text = str(max_players)
	get_node(main_menu + "Balls/BallNum").text = str(max_balls)

# Increment/decrement values of options
func crement(item, x):
	if item == "hp":
		max_hp = clamp(max_hp + x, 1, 5)
	if item == "players":
		max_players = clamp(max_players + x, 2, 8)
	if item == "balls":
		max_balls = clamp(max_balls + x, 1, 10)
		update_balls()
	update_option_nodes()

func update_balls():
	for ball in get_node("Game/Balls").get_children():
		ball.queue_free()
	for i in max_balls:
		var ball = load("res://Ball.tscn").instance()
		ball.position = get_node("Game/TestMap/BallSpawns").get_child(i).position
		get_node("Game/Balls").add_child(ball)

# Set up game, wait for players
func load_game():
	var save_data = File.new()
	save_data.open("user://save.txt", File.WRITE)
	save_data.store_line(str(max_hp))
	save_data.store_line(str(max_players))
	save_data.store_line(str(max_balls))
	save_data.close()
	
	playing = true
	message.text = "Waiting for " + str(max_players) + " players to join..."
	get_node("UILayer/Menu").hide()
	camera.position = get_node("Game/TestMap/DefCamPos").position

# Signal player nodes to begin
func start_game():
	message.text = ""
	for p in player_db:
		p["node"].game_began()
	started = true

# Reset and clear players/balls
func unload_game():
	playing = false
	get_node("Game/ResetTimer").stop()
	camera.position = get_node("Game/TestMap/DefCamPos").position
	camera.zoom = Vector2(1, 1)
	message.text = ""
	player_db.clear()
	for p in players.get_children():
		p.queue_free()
	started = false
	update_balls()
	for b in bars.get_children():
		b.queue_free()
	bars.columns = 1
	get_node("UILayer/Menu").show()

# Create new player
func new_player(id):
	var p_num = player_db.size()
	var new_player = load("res://Player.tscn").instance()
	new_player.name = str(p_num)
	new_player.pad = id
	var new_color = used_colors[0]
	while used_colors.has(new_color):
		randomize()
		new_color = Color.from_hsv((randi() % 18 * 20.0) / 360.0, 1, 1)
	used_colors.append(new_color)
	new_player.modulate = new_color
	
	var new_bar = HBoxContainer.new()
	new_bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	new_bar.modulate = new_color
	new_bar.alignment = BoxContainer.ALIGN_CENTER
	var hp_bar = HBoxContainer.new()
	hp_bar.set("custom_constants/separation", -18)
	for _x in range(max_hp):
		var hp_bit = TextureRect.new()
		hp_bit.texture = load("res://img/hp.png")
		hp_bar.add_child(hp_bit)
	new_bar.add_child(hp_bar)
	bars.add_child(new_bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	new_player.spawn_pos = player_spawns.get_child(p_num).position
	new_player.spawn_rot = player_spawns.get_child(p_num).rotation
	new_player.connect("hit", self, "on_player_hit")
	player_db.append({pad = id, hp = max_hp, color = new_color, hud = hp_bar, node = new_player})
	players.add_child(new_player)
	players.move_child(new_player, 0)

# Manage player health
func on_player_hit(p_num):
	if not (started and playing):
		return
	player_db[p_num]["node"].damage()
	player_db[p_num]["hp"] -= 1
	if player_db[p_num]["hp"] == 0:
		player_db[p_num]["node"].queue_free()
		if player_db[p_num]["pad"] >= 0:
			Input.start_joy_vibration(player_db[p_num]["pad"], .2, .2, .3)
	var hp_bits = player_db[p_num]["hud"].get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(.3, .3, .3, .3)
		if player_db[p_num]["hp"] > i:
			hp_bits[i].modulate = Color(1, 1, 1, 1)

# Checks if a pad is already used
func is_new_pad(id):
	for p in player_db:
		if p["pad"] == id:
			return false
	return true

func _process(_delta):
	# Create player if sensed input, start game when players join
	if player_db.size() < max_players and playing:
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, JOY_START) and is_new_pad(c):
					new_player(c)
	if player_db.size() >= max_players and not started:
		start_game()
	
	# Game has ended, begin unloading
	if started and playing and players.get_child_count() < 2:
		playing = false
		message.text = "Game ended!"
		get_node("Game/ResetTimer").start(3)
	
	# Center camera to average player position, zoom camera to always view all players
	if players.get_child_count() > 0:
		var avg = Vector2.ZERO
		for player in players.get_children():
			avg.x += player.position.x
			avg.y += player.position.y
		camera.position = avg / players.get_child_count()
		
		var max_x = players.get_child(0).position.x
		var min_x = players.get_child(0).position.x
		var max_y = players.get_child(0).position.y
		var min_y = players.get_child(0).position.y
		for player in players.get_children():
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		var new_zoom = Vector2.ZERO
		var new_zoom_x = (abs(max_x - min_x) + zoom_margin) / OS.window_size.x
		var new_zoom_y = (abs(max_y - min_y) + zoom_margin) / OS.window_size.y
		new_zoom = Vector2(max(new_zoom_x, new_zoom_y), max(new_zoom_x, new_zoom_y))
		new_zoom = Vector2(1, 1) if new_zoom < Vector2(1, 1) else new_zoom
		camera.zoom = camera.zoom.linear_interpolate(new_zoom, zoom_accel)
