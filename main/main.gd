extends Node

const PADDLE_TEXTURE = preload("res://paddle/paddle.png")
const BALL_TEXTURE = preload("res://ball/ball.png")
const PADDLE_SCENE = preload("res://paddle/paddle.tscn")
const BALL_SCENE = preload("res://ball/ball.tscn")
const MAP_SCENE = preload("res://map/map.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")
const MOVE_SPEED = 500

var is_playing = false
var initial_max_health = 0
var paddle_data = {}
var ball_data = []
var input_list = {}
var used_inputs = []
var camera_spawn = Vector2()
var paddle_spawns = []
var ball_spawns = []

onready var camera = $Camera
onready var map_parent = $Map
onready var paddle_parent = $Paddles
onready var ball_parent = $Balls
onready var ui = $CanvasLayer/UI
onready var join_timer = $JoinTimer

func _ready():
	get_tree().connect("network_peer_disconnected", self, "handle_peer_disconnect")
	get_tree().connect("connected_to_server", self,"rpc_id", [1, "check_client", Game.VERSION])
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])
	ui.connect("start_game", self, "start_server_game")
	ui.connect("connect_to_server", self, "connect_to_server")
	ui.connect("refresh_servers", self, "refresh_servers")
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])

func _physics_process(_delta):
	if is_playing:
		if Network.peer_id == 1:
			rpc_unreliable("update_objects", paddle_data, ball_data)
			Network.broadcast_server()
		camera.move_and_zoom(paddle_parent.get_children())

func _input(_event):
	if is_playing and OS.is_window_focused():
		if Input.is_key_pressed(KEY_ENTER) and not -1 in input_list.values():
			create_paddle_from_input(-1)
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and not pad in input_list.values():
				create_paddle_from_input(pad)
		if -1 in input_list.values() and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game")
		for pad in input_list.values():
			if Input.is_joy_button_pressed(pad, JOY_START) and Input.is_joy_button_pressed(pad, JOY_SELECT):
				unload_game("You left the game")
				break

func refresh_servers():
	for server in ui.server_parent.get_children():
		server.queue_free()
	var servers = Network.get_servers()
	for ip in servers.keys():
		ui.create_new_server(ip, servers[ip])

func connect_to_server(ip):
	if ip == "":
		ip = ui.ip_input.text
	Game.config.peer_name = ui.name_input.text
	Game.config.ip = ip
	if ip.is_valid_ip_address():
		ui.set_message("Trying to connect...")
		initial_max_health = Game.config.max_health
		Network.setup_client(ip)
		join_timer.start(3)
		ui.toggle_inputs(true)
	else:
		ui.set_message("Invalid IP", 3)
		ui.ip_input.grab_focus()
	Game.save_config()

func handle_peer_disconnect(id):
	var paddles_to_clear = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_parent.get_node(paddle).queue_free()
		ui.bar_parent.get_node(paddle).queue_free()
	ui.bar_parent.columns = max(paddle_data.size(), 1)
	ui.set_message("Client disconnected", 2)

remote func check_client(version):
	var id = get_tree().get_rpc_sender_id()
	if version == Game.VERSION:
		ui.set_message("Client connected", 2)
		rpc_id(id, "start_client_game", paddle_data, Game.config.using_small_map,
				map_parent.modulate, Game.config.max_health, Game.config.ball_count)
	else:
		rpc_id(id, "unload_game", "Different server version (" + Game.VERSION + ")")

remote func start_client_game(paddles, small_map, map_color, health, balls):
	ui.toggle_inputs(false)
	join_timer.stop()
	load_game(small_map, map_color, balls)
	Game.config.max_health = health
	for paddle in paddles:
		create_paddle(paddles[paddle])

func start_server_game():
	Game.config.peer_name = ui.name_input.text
	Network.setup_server()
	var map_color = Color.from_hsv(randf(), 0.8, 1)
	load_game(Game.config.using_small_map, map_color, Game.config.ball_count)

func load_game(small_map, map_color, ball_count):
	Game.save_config()
	map_parent.modulate = map_color
	if small_map:
		map_parent.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_parent.add_child(MAP_SCENE.instance())
	camera.spawn = map_parent.get_child(0).get_node("CameraSpawn").position
	paddle_spawns = map_parent.get_child(0).get_node("PaddleSpawns").get_children()
	ball_spawns = map_parent.get_child(0).get_node("BallSpawns").get_children()
	camera.reset()
	for i in min(ball_count, ball_spawns.size()):
		var ball_node = BALL_SCENE.instance()
		if get_tree().network_peer:
			if Network.peer_id == 1:
				ball_data.append({})
			else:
				ball_node = Sprite.new()
				ball_node.texture = BALL_TEXTURE
		ball_node.position = ball_spawns[i].position
		ball_parent.add_child(ball_node)
	ui.set_message("Press A/Enter to create your paddle", 5)
	ui.menu_node.hide()
	is_playing = true

remote func unload_game(msg):
	is_playing = false
	if get_tree().has_network_peer():
		if Network.peer_id != 1:
			Game.config.max_health = initial_max_health
		Network.reset()
	join_timer.stop()
	input_list.clear()
	used_inputs.clear()
	camera.reset()
	if map_parent.get_child_count() > 0:
		map_parent.get_child(0).queue_free()
	for paddle in paddle_parent.get_children():
		paddle.queue_free()
	paddle_data.clear()
	for ball in ball_parent.get_children():
		ball.queue_free()
	ball_data.clear()
	for bar in ui.bar_parent.get_children():
		bar.queue_free()
	ui.reset(msg)
	refresh_servers()

remotesync func update_objects(paddles, balls):
	if is_playing:
		if Network.peer_id == 1:
			for paddle in paddles:
				var paddle_node = paddle_parent.get_node(paddle)
				paddle_data[paddle].position = paddle_node.position
				paddle_data[paddle].rotation = paddle_node.rotation
				if Network.peer_id == paddles[paddle].id:
					set_paddle_inputs(paddle, get_paddle_inputs(paddle))
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
				if Network.peer_id == paddles[paddle].id:
					rpc_unreliable_id(1, "set_paddle_inputs", paddle, get_paddle_inputs(paddle))
			for ball_index in ball_parent.get_child_count():
				var ball_node = ball_parent.get_child(ball_index)
				ball_node.position = balls[ball_index].position
				ball_node.rotation = balls[ball_index].rotation

func create_paddle_from_input(pad):
	if not pad in used_inputs:
		var data = {
			"name": Game.config.peer_name,
			"id": Network.peer_id,
			"pad": pad,
		}
		used_inputs.append(pad)
		if Network.peer_id == 1:
			create_paddle(data)
		else:
			rpc_id(1, "create_paddle", data)

remote func create_paddle(data):
	var paddle_count = paddle_parent.get_child_count()
	if paddle_count < paddle_spawns.size():
		var paddle_node = PADDLE_SCENE.instance()
		if Network.peer_id != 1:
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
		if Network.peer_id == 1:
			paddle_node.connect("collided", self, "vibrate_pad", [new_name])
			paddle_node.connect("damaged", self, "damage_paddle", [new_name])
		if Network.peer_id == data.id and "pad" in data:
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
		ui.create_bar(paddle_data[new_name], paddle_count)
		if Network.peer_id == 1 and Game.config.is_open_to_lan:
			var new_data = paddle_data[new_name].duplicate(true)
			if Network.peer_id != data.id and "pad" in data:
				new_data.pad = data.pad
			rpc("create_paddle", new_data)
		paddle_parent.add_child(paddle_node)

func get_paddle_inputs(paddle):
	var pad = input_list[paddle]
	var inputs = {
		"velocity": Vector2(),
		"rotation": 0.0,
		"dash": false
	}
	if OS.is_window_focused():
		if pad == -1:
			inputs.velocity.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
			inputs.velocity.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
			inputs.velocity = inputs.velocity.normalized() * MOVE_SPEED
			if inputs.velocity:
				inputs.dash = Input.is_key_pressed(KEY_SHIFT)
			inputs.rotation = deg2rad((int(Input.is_key_pressed(KEY_PERIOD)) - int(Input.is_key_pressed(KEY_COMMA))) * 4)
		else:
			var left_stick = Vector2(Input.get_joy_axis(pad, JOY_ANALOG_LX), Input.get_joy_axis(pad, JOY_ANALOG_LY))
			var right_stick = Vector2(Input.get_joy_axis(pad, JOY_ANALOG_RX), Input.get_joy_axis(pad, JOY_ANALOG_RY))
			if left_stick.length() > 0.2:
				inputs.velocity = left_stick * MOVE_SPEED
				inputs.dash = Input.is_joy_button_pressed(pad, JOY_L2)
			if right_stick.length() > 0.7:
				var paddle_node = paddle_parent.get_node(paddle)
				inputs.rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	return inputs

remote func set_paddle_inputs(paddle, inputs):
	paddle_parent.get_node(paddle).set_inputs(inputs)

remote func vibrate_pad(paddle):
	if is_playing:
		if Network.peer_id == paddle_data[paddle].id:
			Input.start_joy_vibration(input_list[paddle], 0.1, 0.1, 0.1)
		elif Network.peer_id == 1 and Game.config.is_open_to_lan:
			rpc_id(paddle_data[paddle].id, "vibrate_pad", paddle)

remote func damage_paddle(paddle):
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		ui.set_message(paddle_data[paddle].name + " was destroyed", 2)
		if Network.peer_id == 1:
			var paddle_node = paddle_parent.get_node(paddle)
			paddle_node.position = paddle_spawns[paddle_node.get_index()].position
			paddle_node.rotation = paddle_spawns[paddle_node.get_index()].rotation
		paddle_data[paddle].health = Game.config.max_health
	ui.update_bar(paddle, paddle_data[paddle].health)
	if Network.peer_id == 1:
		rpc("damage_paddle", paddle)
