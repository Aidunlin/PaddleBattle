# This contains almost everything code-wise. Bad practice? Maybe.
# I suggest you fold all lines to get a general view of things.

extends Node

# Preloading is pog
const HP_TEXTURE = preload("res://main/hp.png")
const PADDLE_TEXTURE = preload("res://paddle/paddle.png")
const BALL_TEXTURE = preload("res://ball/ball.png")
const PADDLE_SCENE = preload("res://paddle/paddle.tscn")
const BALL_SCENE = preload("res://ball/ball.tscn")
const MAP_SCENE = preload("res://map/map.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")
const VERSION = "Dev Build"
const MOVE_SPEED = 500
const CAMERA_ZOOM = Vector2(1, 1)

var is_playing = false
var is_open_to_lan = true
var using_small_map = false
var peer_id = 1
var peer_name = ""
var initial_max_health = 0
var max_health = 3
var ball_count = 10
var paddle_data = {}
var ball_data = []
var input_list = {}
var camera_spawn = Vector2()
var paddle_spawns = []
var ball_spawns = []

# Onready go brrrr
onready var camera_node = $Camera
onready var map_parent = $Map
onready var paddle_parent = $Paddles
onready var ball_parent = $Balls
onready var message_node = $CanvasLayer/UI/Message
onready var bars_node = $CanvasLayer/UI/HUD/Bars
onready var menu_node = $CanvasLayer/UI/Menu
onready var main_menu = $CanvasLayer/UI/Menu/Main
onready var version_node = $CanvasLayer/UI/Menu/Main/Version
onready var name_input = $CanvasLayer/UI/Menu/Main/NameBar/Name
onready var play_button = $CanvasLayer/UI/Menu/Main/Play
onready var ip_input = $CanvasLayer/UI/Menu/Main/IPBar/IP
onready var join_button = $CanvasLayer/UI/Menu/Main/Join
onready var quit_button = $CanvasLayer/UI/Menu/Main/Quit
onready var options_menu = $CanvasLayer/UI/Menu/Options
onready var open_lan_toggle = $CanvasLayer/UI/Menu/Options/OpenLAN
onready var small_map_toggle = $CanvasLayer/UI/Menu/Options/SmallMap
onready var health_dec_button = $CanvasLayer/UI/Menu/Options/HealthBar/Dec
onready var health_inc_button = $CanvasLayer/UI/Menu/Options/HealthBar/Inc
onready var health_node = $CanvasLayer/UI/Menu/Options/HealthBar/Health
onready var balls_dec_button = $CanvasLayer/UI/Menu/Options/BallsBar/Dec
onready var balls_inc_button = $CanvasLayer/UI/Menu/Options/BallsBar/Inc
onready var balls_node = $CanvasLayer/UI/Menu/Options/BallsBar/Balls
onready var start_button = $CanvasLayer/UI/Menu/Options/Start
onready var back_button = $CanvasLayer/UI/Menu/Options/Back
onready var join_timer = $JoinTimer
onready var message_timer = $MessageTimer

# Load config, connect button and network signals
func _ready():
	version_node.text = VERSION
	var file = File.new()
	if file.file_exists("user://config.json"):
		file.open("user://config.json", File.READ)
		var save = parse_json(file.get_line())
		if "name" in save:
			name_input.text = save.name
		if "ip" in save:
			ip_input.text = save.ip
		if "is_open_to_lan" in save:
			is_open_to_lan = save.is_open_to_lan
			open_lan_toggle.pressed = is_open_to_lan
		if "using_small_map" in save:
			using_small_map = save.using_small_map
			small_map_toggle.pressed = using_small_map
		if "health" in save:
			max_health = save.health
		if "balls" in save:
			ball_count = save.balls
		crement()
		file.close()
	play_button.grab_focus()
	play_button.connect("pressed", self, "switch_menu", [false])
	join_button.connect("pressed", self, "connect_to_server")
	quit_button.connect("pressed", get_tree(), "quit")
	open_lan_toggle.connect("pressed", self, "toggle_lan")
	small_map_toggle.connect("pressed", self, "toggle_small_map")
	health_dec_button.connect("pressed", self, "crement", ["health", -1])
	health_inc_button.connect("pressed", self, "crement", ["health", 1])
	balls_dec_button.connect("pressed", self, "crement", ["balls", -1])
	balls_inc_button.connect("pressed", self, "crement", ["balls", 1])
	start_button.connect("pressed", self, "start_game")
	back_button.connect("pressed", self, "switch_menu", [true])
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])
	message_timer.connect("timeout", self, "set_message")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connected_to_server", self, "rpc_id", [1, "check", VERSION])
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])

# Update objects, modify camera
func _physics_process(_delta):
	if is_playing:
		if peer_id == 1:
			rpc_unreliable("update_objects", paddle_data, ball_data)
		var zoom = CAMERA_ZOOM
		if paddle_parent.get_child_count() > 0:
			var avg = Vector2()
			var max_x = -INF
			var min_x = INF
			var max_y = -INF
			var min_y = INF
			for paddle in paddle_parent.get_children():
				avg += paddle.position
				max_x = max(paddle.position.x, max_x)
				min_x = min(paddle.position.x, min_x)
				max_y = max(paddle.position.y, max_y)
				min_y = min(paddle.position.y, min_y)
			avg /= paddle_parent.get_child_count()
			var zoom_x = (2 * max(max_x - avg.x, avg.x - min_x) + OS.window_size.x / 1.5) / OS.window_size.x
			var zoom_y = (2 * max(max_y - avg.y, avg.y - min_y) + OS.window_size.y / 1.5) / OS.window_size.y
			zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
			if zoom < CAMERA_ZOOM:
				zoom = CAMERA_ZOOM
			camera_node.position = avg
		camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.05)

# Handle various inputs (except movement)
func _input(_event):
	if is_playing and OS.is_window_focused():
		if Input.is_key_pressed(KEY_ENTER) and not -1 in input_list.values():
			new_paddle_from_input(-1)
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and not pad in input_list.values():
				new_paddle_from_input(pad)
		if -1 in input_list.values() and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game")
		for pad in input_list.values():
			if Input.is_joy_button_pressed(pad, JOY_START) and Input.is_joy_button_pressed(pad, JOY_SELECT):
				unload_game("You left the game")
				break

##### -------------------- HELPERS -------------------- #####
##### These helpers are used throughout the script, and even by each other

# Create a new paddle from input
func new_paddle_from_input(pad):
	var data = {
		"name": peer_name,
		"id": peer_id,
		"pad": pad,
	}
	if peer_id == 1:
		create_paddle(data)
	else:
		rpc_id(1, "create_paddle", data)

# Update message and timer
func set_message(new = "", time = 0):
	message_node.text = new
	if time > 0:
		message_timer.start(time)
	elif new != "" and not message_timer.is_stopped():
		message_timer.stop()

# Increment or decrement option
func crement(which = "", value = 0):
	if which == "health":
		max_health = int(clamp(max_health + value, 1, 5))
	elif which == "balls":
		ball_count = int(clamp(ball_count + value, 1, 10))
	health_node.text = str(max_health)
	balls_node.text = str(ball_count)

# Enable/disable inputs
func toggle_inputs(toggle):
	name_input.editable = not toggle
	play_button.disabled = toggle
	ip_input.editable = not toggle
	join_button.disabled = toggle

# Switch menu, grab focus of button
func switch_menu(to_main):
	if to_main:
		play_button.grab_focus()
	else:
		if name_input.text == "":
			set_message("Invalid name", 3)
			return
		start_button.grab_focus()
	main_menu.visible = to_main
	options_menu.visible = not to_main

# Self-explanatory
func toggle_lan():
	is_open_to_lan = not is_open_to_lan

# Self-explanatory
func toggle_small_map():
	using_small_map = not using_small_map

##### -------------------- CLIENT -------------------- #####
##### These functions specifically manage clients

# Check name/ip, attempt connection
func connect_to_server():
	if name_input.text == "":
		set_message("Invalid name", 3)
	else:
		var ip = ip_input.text
		if not ip.is_valid_ip_address():
			if ip != "":
				set_message("Invalid IP", 3)
				return
			ip = "127.0.0.1"
		set_message("Trying to connect...")
		toggle_inputs(true)
		initial_max_health = max_health
		var peer = NetworkedMultiplayerENet.new()
		peer.create_client(ip, 8910)
		get_tree().network_peer = peer
		peer_id = get_tree().get_network_unique_id()
		join_timer.start(5)

# Clear client info on disconnect
func peer_disconnected(id):
	var paddles_to_clear = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_parent.get_node(paddle).queue_free()
		bars_node.get_node(paddle).queue_free()
	bars_node.columns = max(paddle_data.size(), 1)
	set_message("Client disconnected", 2)

# Check client version
remote func check(version):
	var id = get_tree().get_rpc_sender_id()
	if version == VERSION:
		set_message("Client connected", 2)
		rpc_id(id, "start_client_game", paddle_data, using_small_map,
				map_parent.modulate, max_health, ball_count)
	else:
		rpc_id(id, "unload_game", "Different server version (" + VERSION + ")")

# Start game (as client)
remote func start_client_game(paddles, small_map, map_color, health, balls):
	join_timer.stop()
	load_game(small_map, map_color, balls)
	max_health = health
	for paddle in paddles:
		create_paddle(paddles[paddle])

##### -------------------- GAME -------------------- #####
##### Functions for starting, stopping, and updating game sessions

# Start game (as server)
func start_game():
	peer_name = name_input.text
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910)
	get_tree().network_peer = peer
	get_tree().refuse_new_network_connections = not is_open_to_lan
	load_game(using_small_map, Color.from_hsv(randf(), 0.8, 1), ball_count)

# Save config, load map, spawn balls (used by server and client)
func load_game(small_map, map_color, balls):
	var file = File.new()
	file.open("user://config.json", File.WRITE)
	var save = {
		"name": name_input.text,
		"ip": ip_input.text,
		"is_open_to_lan": is_open_to_lan,
		"using_small_map": using_small_map,
		"health": max_health,
		"balls": ball_count,
	}
	file.store_line(to_json(save))
	file.close()
	map_parent.modulate = map_color
	if small_map:
		map_parent.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_parent.add_child(MAP_SCENE.instance())
	camera_spawn = map_parent.get_child(0).get_node("CameraSpawn").position
	paddle_spawns = map_parent.get_child(0).get_node("PaddleSpawns").get_children()
	ball_spawns = map_parent.get_child(0).get_node("BallSpawns").get_children()
	camera_node.position = camera_spawn
	for i in balls:
		if i + 1 > ball_spawns.size():
			break
		var ball_node = BALL_SCENE.instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball_node = Sprite.new()
				ball_node.texture = BALL_TEXTURE
		ball_node.position = ball_spawns[i].position
		ball_parent.add_child(ball_node)
	set_message("Press A/Enter to create your paddle", 5)
	menu_node.hide()
	is_playing = true

# Self-explanatory
remote func unload_game(msg):
	is_playing = false
	if get_tree().has_network_peer():
		if peer_id != 1:
			max_health = initial_max_health
		get_tree().set_deferred("network_peer", null)
		peer_id = 1
	join_timer.stop()
	input_list.clear()
	camera_node.position = Vector2()
	camera_node.smoothing_enabled = false
	map_parent.modulate = Color(1, 1, 1)
	if map_parent.get_child_count() > 0:
		map_parent.get_child(0).queue_free()
	for paddle in paddle_parent.get_children():
		paddle.queue_free()
	paddle_data.clear()
	for ball in ball_parent.get_children():
		ball.queue_free()
	ball_data.clear()
	for bar in bars_node.get_children():
		bar.queue_free()
	bars_node.columns = 1
	menu_node.show()
	toggle_inputs(false)
	switch_menu(true)
	set_message(msg, 3)

# Update paddles and balls (used by server and client)
remotesync func update_objects(paddles, balls):
	if is_playing:
		if peer_id == 1:
			for paddle in paddles:
				var paddle_node = paddle_parent.get_node(paddle)
				paddle_data[paddle].position = paddle_node.position
				paddle_data[paddle].rotation = paddle_node.rotation
				if paddles[paddle].id == peer_id:
					inputs_to_paddle(paddle, get_inputs(paddle))
			for ball_index in ball_parent.get_child_count():
				var ball_node = ball_parent.get_child(ball_index)
				if ball_node.position.length() > 4096:
					ball_node.queue_free()
					var new_ball_node = BALL_SCENE.instance()
					new_ball_node.position = ball_spawns[ball_index].position
					ball_parent.add_child(new_ball_node)
				ball_data[ball_index].position = ball_node.position
				ball_data[ball_index].rotation = ball_node.rotation
		else:
			for paddle in paddles:
				paddle_data[paddle].position = paddles[paddle].position
				paddle_data[paddle].rotation = paddles[paddle].rotation
				var paddle_node = paddle_parent.get_node(paddle)
				paddle_node.position = paddles[paddle].position
				paddle_node.rotation = paddles[paddle].rotation
				if paddles[paddle].id == peer_id:
					rpc_unreliable_id(1, "inputs_to_paddle", paddle, get_inputs(paddle))
			for ball_index in ball_parent.get_child_count():
				var ball_node = ball_parent.get_child(ball_index)
				ball_node.position = balls[ball_index].position
				ball_node.rotation = balls[ball_index].rotation

##### -------------------- PADDLE -------------------- #####
##### Manages paddle creation and handles inputs/damage

# Create paddle, hud, and data (server first, then send to clients)
remote func create_paddle(data):
	camera_node.smoothing_enabled = true
	var paddle_node = PADDLE_SCENE.instance()
	var paddle_count = paddle_parent.get_child_count()
	if paddle_count == paddle_spawns.size():
		return
	if peer_id != 1:
		paddle_node = Sprite.new()
		paddle_node.texture = PADDLE_TEXTURE
	if "position" in data and "rotation" in data:
		paddle_node.position = data.position
		paddle_node.rotation = data.rotation
	else:
		paddle_node.position = paddle_spawns[paddle_count].position
		paddle_node.rotation = paddle_spawns[paddle_count].rotation
	if "color" in data:
		paddle_node.modulate = data.color
	else:
		paddle_node.modulate = Color.from_hsv(randf(), 0.8, 1)
	var name_count = 1
	for paddle in paddle_parent.get_children():
		if data.name in paddle.name:
			name_count += 1
	var new_name = data.name
	if name_count > 1:
		new_name += str(name_count)
	paddle_node.name = new_name
	if peer_id == 1:
		paddle_node.connect("collided", self, "vibrate", [new_name])
		paddle_node.connect("damaged", self, "damage", [new_name])
	if peer_id == data.id and "pad" in data:
		input_list[new_name] = data.pad
	var bar = VBoxContainer.new()
	bar.name = new_name
	bar.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = paddle_node.modulate
	bar.alignment = BoxContainer.ALIGN_CENTER
	var label = Label.new()
	label.text = new_name
	label.align = Label.ALIGN_CENTER
	bar.add_child(label)
	var hp_bar = HBoxContainer.new()
	hp_bar.alignment = BoxContainer.ALIGN_CENTER
	hp_bar.set("custom_constants/separation", -20)
	for i in max_health:
		var bit = TextureRect.new()
		bit.texture = HP_TEXTURE
		if "health" in data and data.health <= i:
			bit.modulate.a = 0.1
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars_node.add_child(bar)
	bars_node.columns = paddle_count + 1
	paddle_data[new_name] = {
		"position": paddle_node.position,
		"rotation": paddle_node.rotation,
		"name": new_name,
		"id": data.id,
		"color": paddle_node.modulate,
	}
	if "health" in data:
		paddle_data[new_name].health = data.health
	else:
		paddle_data[new_name].health = max_health
	if peer_id == 1 and is_open_to_lan:
		var new_data = paddle_data[new_name].duplicate(true)
		if data.id != peer_id and "pad" in data:
			new_data.pad = data.pad
		rpc("create_paddle", new_data)
	paddle_parent.add_child(paddle_node)

# Get input data for paddle on this peer
func get_inputs(paddle):
	var pad = input_list[paddle]
	var input = {
		"velocity": Vector2(),
		"rotation": 0.0,
		"dash": false
	}
	if not OS.is_window_focused():
		return input
	if pad == -1:
		input.velocity.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
		input.velocity.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
		input.velocity = input.velocity.normalized() * MOVE_SPEED
		if input.velocity.length() > 0:
			input.dash = Input.is_key_pressed(KEY_SHIFT)
		input.rotation = deg2rad((int(Input.is_key_pressed(KEY_PERIOD)) - int(Input.is_key_pressed(KEY_COMMA))) * 4)
	else:
		var left_stick = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
		var right_stick = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
		if left_stick.length() > 0.2:
			input.velocity = left_stick * MOVE_SPEED
			input.dash = Input.is_joy_button_pressed(pad, JOY_L2)
		if right_stick.length() > 0.7:
			var paddle_node = paddle_parent.get_node(paddle)
			input.rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	return input

# Send input data to paddle (as server)
remote func inputs_to_paddle(paddle, input):
	paddle_parent.get_node(paddle).inputs(input)

# Vibrate controller (server first, or send to correct client)
remote func vibrate(paddle):
	if is_playing:
		if paddle_data[paddle].id == peer_id:
			Input.start_joy_vibration(input_list[paddle], 0.1, 0.1, 0.1)
		elif peer_id == 1 and is_open_to_lan:
			rpc_id(paddle_data[paddle].id, "vibrate", paddle)

# Manage health and respawning (server first, then send to clients)
remote func damage(paddle):
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		set_message(paddle_data[paddle].name + " was destroyed", 2)
		if peer_id == 1:
			var paddle_node = paddle_parent.get_node(paddle)
			paddle_node.position = paddle_spawns[paddle_node.get_index()].position
			paddle_node.rotation = paddle_spawns[paddle_node.get_index()].rotation
		paddle_data[paddle].health = max_health
	var health_bits = bars_node.get_node(paddle).get_child(1).get_children()
	for i in max_health:
		if paddle_data[paddle].health > i:
			health_bits[i].modulate.a = 1.0
		else:
			health_bits[i].modulate.a = 0.1
	if peer_id == 1:
		rpc("damage", paddle)
