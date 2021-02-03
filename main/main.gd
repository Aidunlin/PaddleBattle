extends Node

const HP_TEXTURE = preload("res://main/hp.png")
const PADDLE_SCENE = preload("res://paddle/paddle.tscn")
const CLIENT_PADDLE_SCENE = preload("res://paddle/clientpaddle.tscn")
const BALL_SCENE = preload("res://ball/ball.tscn")
const CLIENT_BALL_SCENE = preload("res://ball/clientball.tscn")
const MAP_SCENE = preload("res://map/map.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")

const VERSION = "Dev Build"
const MOVE_SPEED = 500
const CAMERA_ZOOM = Vector2(1, 1)

var is_playing = false
var is_open_to_lan = true
var using_small_map = false
var peer_id = 1

var initial_max_health = 0
var max_health = 3
var ball_count = 10

var peer_name = ""
var paddle_data = {}
var ball_data = []
var input_list = {}
var hues = []

var camera_spawn = Vector2()
var paddle_spawns = []
var ball_spawns = []

onready var map_node = $Map
onready var camera_node = $Camera
onready var paddle_nodes = $Paddles
onready var ball_nodes = $Balls

onready var message_node = $CanvasLayer/UI/Message
onready var bars_node = $CanvasLayer/UI/HUD/Bars
onready var menu_node = $CanvasLayer/UI/Menu

onready var main_menu_node = $CanvasLayer/UI/Menu/Main
onready var version_node = $CanvasLayer/UI/Menu/Main/Version
onready var name_input = $CanvasLayer/UI/Menu/Main/NameBar/Name
onready var play_button = $CanvasLayer/UI/Menu/Main/Play
onready var ip_input = $CanvasLayer/UI/Menu/Main/IPBar/IP
onready var join_button = $CanvasLayer/UI/Menu/Main/Join
onready var quit_button = $CanvasLayer/UI/Menu/Main/Quit

onready var options_menu_node = $CanvasLayer/UI/Menu/Options
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


func _ready():
	version_node.text = VERSION
	load_config()
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
	get_tree().connect("connected_to_server", self, "connected")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])


func _physics_process(_delta):
	if is_playing and peer_id == 1:
		rpc_unreliable("update_objects", paddle_data, ball_data)
	
	var zoom = CAMERA_ZOOM
	if is_playing and paddle_nodes.get_child_count() > 0:
		camera_node.smoothing_enabled = true
		var avg = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for paddle in paddle_nodes.get_children():
			avg += paddle.position
			max_x = max(paddle.position.x, max_x)
			min_x = min(paddle.position.x, min_x)
			max_y = max(paddle.position.y, max_y)
			min_y = min(paddle.position.y, min_y)
		avg /= paddle_nodes.get_child_count()
		var zoom_x = (2 * max(max_x - avg.x, avg.x - min_x) + OS.window_size.x / 1.5) / OS.window_size.x
		var zoom_y = (2 * max(max_y - avg.y, avg.y - min_y) + OS.window_size.y / 1.5) / OS.window_size.y
		zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		if zoom < CAMERA_ZOOM:
			zoom = CAMERA_ZOOM
		camera_node.position = avg
	
	if camera_node.zoom > zoom:
		camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.01)
	else:
		camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.1)


func _input(_event):
	if not OS.is_window_focused():
		return
	
	if is_playing and paddle_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and not -1 in input_list.values():
			var data = {
				"name": peer_name,
				"id": peer_id,
				"pad": -1,
			}
			if peer_id == 1:
				create_paddle(data)
			else:
				rpc_id(1, "create_paddle", data)
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and not pad in input_list.values():
				var data = {
					"name": peer_name,
					"id": peer_id,
					"pad": pad,
				}
				if peer_id == 1:
					create_paddle(data)
				else:
					rpc_id(1, "create_paddle", data)
	
	if is_playing:
		if -1 in input_list.values() and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game")
			return
		for pad in input_list.values():
			if Input.is_joy_button_pressed(pad, JOY_START) and Input.is_joy_button_pressed(pad, JOY_SELECT):
				unload_game("You left the game")
				return
	
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		connect_to_server()
	
	if options_menu_node.visible and Input.is_action_just_released("ui_cancel"):
		switch_menu(true)



##### HELPERS #####


func set_message(new = "", time = 0):
	message_node.text = new
	if time > 0:
		message_timer.start(time)
	elif new != "" and not message_timer.is_stopped():
		message_timer.stop()


func crement(which = "", value = 0):
	if which == "health":
		max_health = int(clamp(max_health + value, 1, 5))
	elif which == "balls":
		ball_count = int(clamp(ball_count + value, 1, 10))
	health_node.text = str(max_health)
	balls_node.text = str(ball_count)


func toggle_buttons(toggle):
	name_input.editable = not toggle
	play_button.disabled = toggle
	ip_input.editable = not toggle
	join_button.disabled = toggle


func switch_menu(to_main):
	if not to_main:
		if get_peer_name() == "":
			return
		start_button.grab_focus()
	else:
		play_button.grab_focus()
	
	main_menu_node.visible = to_main
	options_menu_node.visible = not to_main


func toggle_lan():
	is_open_to_lan = not is_open_to_lan


func toggle_small_map():
	using_small_map = not using_small_map


func get_peer_name():
	var new_name = name_input.text
	if new_name == "":
		set_message("Invalid name", 3)
	peer_name = new_name
	return new_name


func save_config():
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


func load_config():
	var file = File.new()
	if not file.file_exists("user://config.json"):
		return
	file.open("user://config.json", File.READ)
	var save = parse_json(file.get_line())
	if save.has("name"):
		name_input.text = save.name
	if save.has("ip"):
		ip_input.text = save.ip
	if save.has("is_open_to_lan"):
		is_open_to_lan = save.is_open_to_lan
		open_lan_toggle.pressed = is_open_to_lan
	if save.has("using_small_map"):
		using_small_map = save.using_small_map
		small_map_toggle.pressed = using_small_map
	if save.has("health"):
		max_health = save.health
	if save.has("balls"):
		ball_count = save.balls
	crement()
	file.close()



##### CLIENT #####


func connect_to_server():
	if get_peer_name() == "":
		return
	var ip = ip_input.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_message("Invalid IP", 3)
			return
		ip = "127.0.0.1"
	set_message("Trying to connect...")
	toggle_buttons(true)
	initial_max_health = max_health
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().network_peer = peer
	peer_id = get_tree().get_network_unique_id()
	join_timer.start(5)


func peer_disconnected(id):
	var paddles_to_clear = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_nodes.get_node(paddle).queue_free()
		bars_node.get_node(paddle).queue_free()
	bars_node.columns = int(clamp(paddle_data.size(), 1, 8))
	set_message("Client disconnected", 2)


func connected():
	rpc_id(1, "check", VERSION)


remote func check(version):
	var id = get_tree().get_rpc_sender_id()
	if version != VERSION:
		rpc_id(id, "unload_game", "Different server version (" + VERSION + ")")
		return
	set_message("Client connected", 2)
	rpc_id(id, "start_client_game", paddle_data, using_small_map, map_node.modulate, max_health, ball_count)


remote func start_client_game(paddles, small_map, map_color, health, balls):
	join_timer.stop()
	load_game(small_map, map_color, balls)
	max_health = health
	for paddle in paddles:
		create_paddle(paddles[paddle])



##### GAME #####


func start_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().network_peer = peer
	get_tree().refuse_new_network_connections = not is_open_to_lan
	var new_hue = 250
	while new_hue > 200 and new_hue < 300:
		randomize()
		new_hue = randf() * 360
	hues.append(new_hue)
	load_game(using_small_map, Color.from_hsv(new_hue / 360.0, 1, 1), ball_count)


func load_game(small_map, map_color, balls):
	save_config()
	menu_node.hide()
	map_node.modulate = map_color
	if small_map:
		map_node.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_node.add_child(MAP_SCENE.instance())
	camera_spawn = map_node.get_child(0).get_node("CameraSpawn").position
	paddle_spawns = map_node.get_child(0).get_node("PaddleSpawns").get_children()
	ball_spawns = map_node.get_child(0).get_node("BallSpawns").get_children()
	create_balls(balls)
	set_message("Press A/Enter to create your paddle", 5)
	is_playing = true
	camera_node.position = camera_spawn


remote func unload_game(msg = ""):
	is_playing = false
	if get_tree().has_network_peer():
		if peer_id != 1:
			max_health = initial_max_health
		get_tree().set_deferred("network_peer", null)
		peer_id = 1
	join_timer.stop()
	set_message(msg, 3)
	input_list.clear()
	hues.clear()
	for paddle in paddle_nodes.get_children():
		paddle.queue_free()
	paddle_data.clear()
	for ball in ball_nodes.get_children():
		ball.queue_free()
	ball_data.clear()
	for bar in bars_node.get_children():
		bar.queue_free()
	bars_node.columns = 1
	if map_node.get_child_count() > 0:
		map_node.get_child(0).queue_free()
	map_node.modulate = Color(0, 0, 0)
	menu_node.show()
	switch_menu(true)
	camera_node.position = Vector2()
	camera_node.smoothing_enabled = false
	toggle_buttons(false)


remotesync func update_objects(paddles, balls):
	if not is_playing:
		return
	
	if peer_id == 1:
		for paddle in paddles:
			var paddle_node = paddle_nodes.get_node(paddle)
			paddle_data[paddle].position = paddle_node.position
			paddle_data[paddle].rotation = paddle_node.rotation
			if paddles[paddle].id == peer_id:
				inputs_to_paddle(paddle, get_inputs(paddle, input_list[paddle]))
		for ball in ball_nodes.get_child_count():
			var ball_node = ball_nodes.get_child(ball)
			if ball_node.position.length() > 4096:
				ball_node.queue_free()
				var new_ball_node = BALL_SCENE.instance()
				new_ball_node.position = ball_spawns[ball].position
				ball_nodes.add_child(new_ball_node)
			ball_data[ball].position = ball_node.position
			ball_data[ball].rotation = ball_node.rotation
	
	else:
		for paddle in paddles:
			paddle_data[paddle].position = paddles[paddle].position
			paddle_data[paddle].rotation = paddles[paddle].rotation
			var paddle_node = paddle_nodes.get_node(paddle)
			paddle_node.position = paddles[paddle].position
			paddle_node.rotation = paddles[paddle].rotation
			if paddles[paddle].id == peer_id:
				rpc_unreliable_id(1, "inputs_to_paddle", paddle, get_inputs(paddle, input_list[paddle]))
		for ball in ball_nodes.get_child_count():
			var ball_node = ball_nodes.get_child(ball)
			ball_node.position = balls[ball].position
			ball_node.rotation = balls[ball].rotation



##### PADDLE #####


remote func create_paddle(data = {}):
	var paddle_count = paddle_nodes.get_child_count()
	var paddle_node = PADDLE_SCENE.instance()
	
	if peer_id != 1:
		paddle_node = CLIENT_PADDLE_SCENE.instance()
	
	if data.has("position") and data.has("rotation"):
		paddle_node.position = data.position
		paddle_node.rotation = data.rotation
	else:
		paddle_node.position = paddle_spawns[paddle_count].position
		paddle_node.rotation = paddle_spawns[paddle_count].rotation
	
	if data.has("color"):
		paddle_node.modulate = data.color
	else:
		var new_hue = 250
		while new_hue > 200 and new_hue < 300 or new_hue in hues:
			randomize()
			new_hue = randf() * 360
			print(new_hue)
		hues.append(new_hue)
		paddle_node.modulate = Color.from_hsv(new_hue / 360.0, 1, 1)
	
	var name_count = 1
	for paddle in paddle_nodes.get_children():
		if data.name in paddle.name:
			name_count += 1
	var new_name = data.name
	if name_count > 1:
		new_name += str(name_count)
	paddle_node.name = new_name
	
	if peer_id == 1:
		paddle_node.connect("vibrate", self, "vibrate", [new_name])
		paddle_node.connect("damaged", self, "damaged", [new_name])
	
	if peer_id == data.id:
		if data.has("pad"):
			input_list[new_name] = data.pad
		else:
			input_list[new_name] = -2
	
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
	hp_bar.set("custom_constants/separation", -18)
	for i in max_health:
		var bit = TextureRect.new()
		bit.texture = HP_TEXTURE
		if data.has("health"):
			if data.health > i:
				bit.modulate.a = 1.0
			else:
				bit.modulate.a = 0.1
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars_node.add_child(bar)
	bars_node.columns = int(clamp(bars_node.get_child_count(), 1, 8))
	
	paddle_data[new_name] = {
		"position": paddle_node.position,
		"rotation": paddle_node.rotation,
		"spawn_position": paddle_node.position,
		"spawn_rotation": paddle_node.rotation,
		"name": new_name,
		"id": data.id,
		"color": paddle_node.modulate,
	}
	
	if data.has("health"):
		paddle_data[new_name].health = data.health
	else:
		paddle_data[new_name].health = max_health
	
	if peer_id == 1 and is_open_to_lan:
		var new_data = paddle_data[new_name].duplicate(true)
		if data.id != peer_id:
			if data.has("pad"):
				new_data.pad = data.pad
		rpc("create_paddle", new_data)
	
	paddle_nodes.add_child(paddle_node)
	paddle_nodes.move_child(paddle_node, 0)


func get_inputs(paddle, pad):
	if pad == -2 or not OS.is_window_focused():
		return {
			"velocity": Vector2(),
			"rotation": 0,
			"dash": false,
		}
	
	var input_velocity = Vector2()
	var input_rotation = 0.0
	var dash = false
	
	if pad == -1:
		input_velocity.x = int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A))
		input_velocity.y = int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
		input_velocity = input_velocity.normalized()
		if int(Input.is_key_pressed(KEY_SHIFT)):
			dash = true
		input_rotation = deg2rad((int(Input.is_key_pressed(KEY_PERIOD)) - int(Input.is_key_pressed(KEY_COMMA))) * 4)
	
	else:
		var left_stick = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
		var right_stick = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
		if left_stick.length() > 0.2:
			input_velocity = left_stick
			if Input.is_joy_button_pressed(pad, JOY_L2):
				dash = true
		if right_stick.length() > 0.7:
			var paddle_node = paddle_nodes.get_node(paddle)
			input_rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	
	return {
		"velocity": input_velocity * MOVE_SPEED,
		"rotation": input_rotation,
		"dash": dash,
	}


remote func inputs_to_paddle(paddle, input):
	paddle_nodes.get_node(paddle).inputs(input)


remote func vibrate(paddle):
	if not is_playing:
		return
	
	if paddle_data[paddle].id == peer_id:
		Input.start_joy_vibration(input_list[paddle], 0.1, 0.1, 0.1)
	elif peer_id == 1 and is_open_to_lan:
		rpc_id(paddle_data[paddle].id, "vibrate", paddle)


remote func damaged(paddle):
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		set_message(paddle_data[paddle].name + " was destroyed", 2)
		if peer_id == 1:
			paddle_nodes.get_node(paddle).position = paddle_data[paddle].spawn_position
			paddle_nodes.get_node(paddle).rotation = paddle_data[paddle].spawn_rotation
		paddle_data[paddle].health = max_health
	
	var health_bits = bars_node.get_node(paddle).get_child(1).get_children()
	for i in max_health:
		if paddle_data[paddle].health > i:
			health_bits[i].modulate.a = 1.0
		else:
			health_bits[i].modulate.a = 0.1
	
	if peer_id == 1:
		rpc("damaged", paddle)



##### BALL #####


func create_balls(count):
	for i in count:
		if i + 1 > ball_spawns.size():
			return
		
		var ball_node = BALL_SCENE.instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball_node = CLIENT_BALL_SCENE.instance()
		ball_node.position = ball_spawns[i].position
		ball_nodes.add_child(ball_node)
