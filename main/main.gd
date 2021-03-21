extends Node

const PADDLE_TEXTURE = preload("res://paddle/paddle.png")
const BALL_TEXTURE = preload("res://ball/ball.png")
const PADDLE_SCENE = preload("res://paddle/paddle.tscn")
const BALL_SCENE = preload("res://ball/ball.tscn")
const MAP_SCENE = preload("res://map/map.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")
const MOVE_SPEED = 500
const CAMERA_ZOOM = Vector2(1, 1)

var is_playing = false
var initial_max_health = 0
var paddle_data = {}
var ball_data = []
var input_list = {}
var used_inputs = []
var camera_spawn = Vector2()
var paddle_spawns = []
var ball_spawns = []

onready var camera_node = $Camera
onready var map_parent = $Map
onready var paddle_parent = $Paddles
onready var ball_parent = $Balls
onready var network_node = $Network
onready var ui_node = $CanvasLayer/UI
onready var join_timer = $JoinTimer

# Load config, connect UI and network signals
func _ready():
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])
	ui_node.connect("start_game", self, "start_server_game")
	ui_node.connect("connect_to_server", self, "connect_to_server")
	ui_node.connect("refresh_servers", self, "refresh_servers")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connected_to_server", self, "rpc_id", [1, "check", Game.VERSION])
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])

# Update objects, modify camera
func _physics_process(_delta):
	if is_playing:
		if network_node.peer_id == 1:
			rpc_unreliable("update_objects", paddle_data, ball_data)
			network_node.broadcast_server()
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

func refresh_servers():
	for server in ui_node.server_parent.get_children():
		server.queue_free()
	var servers = network_node.get_servers()
	for ip in servers.keys():
		ui_node.create_new_server(ip, servers[ip])

func connect_to_server(ip):
	if ip == "":
		ip = ui_node.ip_input.text
	Game.config.peer_name = ui_node.name_input.text
	Game.config.ip = ip
	if ip.is_valid_ip_address():
		ui_node.set_message("Trying to connect...")
		initial_max_health = Game.config.max_health
		network_node.setup_client(ip)
		join_timer.start(3)
		ui_node.toggle_inputs(true)
	else:
		ui_node.set_message("Invalid IP", 3)
		ui_node.ip_input.grab_focus()
	Game.save_config()

func peer_disconnected(id):
	var paddles_to_clear = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_parent.get_node(paddle).queue_free()
		ui_node.bar_parent.get_node(paddle).queue_free()
	ui_node.bar_parent.columns = max(paddle_data.size(), 1)
	ui_node.set_message("Client disconnected", 2)

# Check client version
remote func check(version):
	var id = get_tree().get_rpc_sender_id()
	if version == Game.VERSION:
		ui_node.set_message("Client connected", 2)
		rpc_id(id, "start_client_game", paddle_data, Game.config.using_small_map,
				map_parent.modulate, Game.config.max_health, Game.config.ball_count)
	else:
		rpc_id(id, "unload_game", "Different server version (" + Game.VERSION + ")")

remote func start_client_game(paddles, small_map, map_color, health, balls):
	ui_node.toggle_inputs(false)
	join_timer.stop()
	load_game(small_map, map_color, balls)
	Game.config.max_health = health
	for paddle in paddles:
		create_paddle(paddles[paddle])

func start_server_game():
	Game.config.peer_name = ui_node.name_input.text
	network_node.setup_server()
	load_game(Game.config.using_small_map, Color.from_hsv(randf(), 0.8, 1), Game.config.ball_count)

# Save config, load map, spawn balls
func load_game(small_map, map_color, balls):
	Game.save_config()
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
			if network_node.peer_id == 1:
				ball_data.append({})
			else:
				ball_node = Sprite.new()
				ball_node.texture = BALL_TEXTURE
		ball_node.position = ball_spawns[i].position
		ball_parent.add_child(ball_node)
	ui_node.set_message("Press A/Enter to create your paddle", 5)
	ui_node.menu_node.hide()
	is_playing = true

remote func unload_game(msg):
	is_playing = false
	if get_tree().has_network_peer():
		if network_node.peer_id != 1:
			Game.config.max_health = initial_max_health
		network_node.reset()
	join_timer.stop()
	input_list.clear()
	used_inputs.clear()
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
	for bar in ui_node.bar_parent.get_children():
		bar.queue_free()
	ui_node.reset(msg)
	refresh_servers()

# Update paddles and balls (used by server and client)
remotesync func update_objects(paddles, balls):
	if is_playing:
		if network_node.peer_id == 1:
			for paddle in paddles:
				var paddle_node = paddle_parent.get_node(paddle)
				paddle_data[paddle].position = paddle_node.position
				paddle_data[paddle].rotation = paddle_node.rotation
				if paddles[paddle].id == network_node.peer_id:
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
				if paddles[paddle].id == network_node.peer_id:
					rpc_unreliable_id(1, "inputs_to_paddle", paddle, get_inputs(paddle))
			for ball_index in ball_parent.get_child_count():
				var ball_node = ball_parent.get_child(ball_index)
				ball_node.position = balls[ball_index].position
				ball_node.rotation = balls[ball_index].rotation

func new_paddle_from_input(pad):
	if not pad in used_inputs:
		var data = {
			"name": Game.config.peer_name,
			"id": network_node.peer_id,
			"pad": pad,
		}
		used_inputs.append(pad)
		if network_node.peer_id == 1:
			create_paddle(data)
		else:
			rpc_id(1, "create_paddle", data)

# Create paddle, hud, and data (server first, then send to clients)
remote func create_paddle(data):
	camera_node.smoothing_enabled = true
	var paddle_node = PADDLE_SCENE.instance()
	var paddle_count = paddle_parent.get_child_count()
	if paddle_count == paddle_spawns.size():
		return
	if network_node.peer_id != 1:
		paddle_node = Sprite.new()
		paddle_node.texture = PADDLE_TEXTURE
	var name_count = 1
	for paddle in paddle_parent.get_children():
		if data.name in paddle.name:
			name_count += 1
	var new_name = data.name
	if name_count > 1:
		new_name += str(name_count)
	paddle_node.name = new_name
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
	if network_node.peer_id == 1:
		paddle_node.connect("collided", self, "vibrate", [new_name])
		paddle_node.connect("damaged", self, "damage", [new_name])
	if network_node.peer_id == data.id and "pad" in data:
		input_list[new_name] = data.pad
	paddle_data[new_name] = {
		"id": data.id,
		"name": new_name,
		"position": paddle_node.position,
		"rotation": paddle_node.rotation,
		"color": paddle_node.modulate,
	}
	if "health" in data:
		paddle_data[new_name].health = data.health
	else:
		paddle_data[new_name].health = Game.config.max_health
	ui_node.create_bar(paddle_data[new_name], paddle_count)
	if network_node.peer_id == 1 and Game.config.is_open_to_lan:
		var new_data = paddle_data[new_name].duplicate(true)
		if data.id != network_node.peer_id and "pad" in data:
			new_data.pad = data.pad
		rpc("create_paddle", new_data)
	paddle_parent.add_child(paddle_node)

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
		if paddle_data[paddle].id == network_node.peer_id:
			Input.start_joy_vibration(input_list[paddle], 0.1, 0.1, 0.1)
		elif network_node.peer_id == 1 and Game.config.is_open_to_lan:
			rpc_id(paddle_data[paddle].id, "vibrate", paddle)

# Manage health and respawning (server first, then send to clients)
remote func damage(paddle):
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		ui_node.set_message(paddle_data[paddle].name + " was destroyed", 2)
		if network_node.peer_id == 1:
			var paddle_node = paddle_parent.get_node(paddle)
			paddle_node.position = paddle_spawns[paddle_node.get_index()].position
			paddle_node.rotation = paddle_spawns[paddle_node.get_index()].rotation
		paddle_data[paddle].health = Game.config.max_health
	ui_node.update_bar(paddle, paddle_data[paddle].health)
	if network_node.peer_id == 1:
		rpc("damage", paddle)
