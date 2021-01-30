extends Node

const HP_TEXTURE: StreamTexture = preload("res://main/hp.png")
const PADDLE_SCENE: PackedScene = preload("res://paddle/paddle.tscn")
const CLIENT_PADDLE_SCENE: PackedScene = preload("res://paddle/clientpaddle.tscn")
const BALL_SCENE: PackedScene = preload("res://ball/ball.tscn")
const CLIENT_BALL_SCENE: PackedScene = preload("res://ball/clientball.tscn")
const MAP_SCENE: PackedScene = preload("res://map/map.tscn")
const SMALL_MAP_SCENE: PackedScene = preload("res://map/smallmap.tscn")

const VERSION: String = "Dev Build"
const MOVE_SPEED: int = 500
const CAMERA_ZOOM: Vector2 = Vector2(1, 1)

var is_playing: bool = false
var is_open_to_lan: bool = true
var using_small_map: bool = false
var peer_id: int = 1

var initial_max_health: int = 0
var max_health: int = 3
var ball_count: int = 10

var peer_name: String = ""
var paddle_data: Dictionary = {}
var ball_data: Array = []
var input_list: Dictionary = {}

var camera_spawn: Vector2 = Vector2()
var paddle_spawns: Array = []
var ball_spawns: Array = []

onready var map_node: Node2D = get_node("Map")
onready var camera_node: Camera2D = get_node("Camera")
onready var paddle_nodes: Node2D = get_node("Paddles")
onready var ball_nodes: Node2D = get_node("Balls")

onready var message_node: Label = get_node("CanvasLayer/UI/Message")
onready var bars_node: GridContainer = get_node("CanvasLayer/UI/HUD/Bars")
onready var menu_node: CenterContainer = get_node("CanvasLayer/UI/Menu")

onready var main_menu_node: VBoxContainer = get_node("CanvasLayer/UI/Menu/Main")
onready var version_node: Label = get_node("CanvasLayer/UI/Menu/Main/Version")
onready var name_input: LineEdit = get_node("CanvasLayer/UI/Menu/Main/NameBar/Name")
onready var play_button: Button = get_node("CanvasLayer/UI/Menu/Main/Play")
onready var ip_input: LineEdit = get_node("CanvasLayer/UI/Menu/Main/IPBar/IP")
onready var join_button: Button = get_node("CanvasLayer/UI/Menu/Main/Join")

onready var options_menu_node: VBoxContainer = get_node("CanvasLayer/UI/Menu/Options")
onready var open_lan_toggle: CheckBox = get_node("CanvasLayer/UI/Menu/Options/OpenLAN")
onready var small_map_toggle: CheckBox = get_node("CanvasLayer/UI/Menu/Options/SmallMap")
onready var health_dec_button: Button = get_node("CanvasLayer/UI/Menu/Options/HealthBar/Dec")
onready var health_inc_button: Button = get_node("CanvasLayer/UI/Menu/Options/HealthBar/Inc")
onready var health_node: Label = get_node("CanvasLayer/UI/Menu/Options/HealthBar/Health")
onready var balls_dec_button: Button = get_node("CanvasLayer/UI/Menu/Options/BallsBar/Dec")
onready var balls_inc_button: Button = get_node("CanvasLayer/UI/Menu/Options/BallsBar/Inc")
onready var balls_node: Label = get_node("CanvasLayer/UI/Menu/Options/BallsBar/Balls")
onready var start_button: Button = get_node("CanvasLayer/UI/Menu/Options/Start")
onready var back_button: Button = get_node("CanvasLayer/UI/Menu/Options/Back")

onready var join_timer: Timer = get_node("JoinTimer")
onready var message_timer: Timer = get_node("MessageTimer")


func _ready() -> void:
	version_node.text = VERSION
	load_config()
	play_button.grab_focus()
	play_button.connect("pressed", self, "toggle_menus", [false])
	join_button.connect("pressed", self, "connect_to_server")
	open_lan_toggle.connect("pressed", self, "toggle_lan")
	small_map_toggle.connect("pressed", self, "toggle_small_map")
	health_dec_button.connect("pressed", self, "crement", ["health", -1])
	health_inc_button.connect("pressed", self, "crement", ["health", 1])
	balls_dec_button.connect("pressed", self, "crement", ["balls", -1])
	balls_inc_button.connect("pressed", self, "crement", ["balls", 1])
	start_button.connect("pressed", self, "start_game")
	back_button.connect("pressed", self, "toggle_menus", [true])
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])
	message_timer.connect("timeout", self, "set_message")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connected_to_server", self, "connected")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])


func _physics_process(_delta: float) -> void:
	# Update objects over LAN
	if is_playing and peer_id == 1:
		rpc_unreliable("update_objects", paddle_data, ball_data)
	
	# Modify camera to always show paddles
	var zoom: Vector2 = CAMERA_ZOOM
	if is_playing and paddle_nodes.get_child_count() > 0:
		var avg: Vector2 = Vector2()
		var max_x: float = -INF
		var min_x: float = INF
		var max_y: float = -INF
		var min_y: float = INF
		for paddle in paddle_nodes.get_children():
			avg += paddle.position
			max_x = max(paddle.position.x, max_x)
			min_x = min(paddle.position.x, min_x)
			max_y = max(paddle.position.y, max_y)
			min_y = min(paddle.position.y, min_y)
		avg /= paddle_nodes.get_child_count()
		var zoom_x: float = (2 * max(max_x - avg.x, avg.x - min_x) + OS.window_size.x / 1.5) / OS.window_size.x
		var zoom_y: float = (2 * max(max_y - avg.y, avg.y - min_y) + OS.window_size.y / 1.5) / OS.window_size.y
		zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		zoom = CAMERA_ZOOM if zoom < CAMERA_ZOOM else zoom
		camera_node.position = avg
	camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.01 if camera_node.zoom > zoom else 0.1)


func _input(_event: InputEvent) -> void:
	if not OS.is_window_focused():
		return
	
	# Create paddle if sensed input
	if is_playing and paddle_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and is_new_input("keys", 0):
			if peer_id == 1:
				create_paddle({name = peer_name, keys = 0, id = peer_id})
			else:
				rpc_id(1, "create_paddle", {name = peer_name, keys = 0, id = peer_id})
		if Input.is_key_pressed(KEY_KP_ENTER) and is_new_input("keys", 1):
			if peer_id == 1:
				create_paddle({name = peer_name, keys = 1, id = peer_id})
			else:
				rpc_id(1, "create_paddle", {name = peer_name, keys = 1, id = peer_id})
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and is_new_input("pad", pad):
				if peer_id == 1:
					create_paddle({name = peer_name, pad = pad, id = peer_id})
				else:
					rpc_id(1, "create_paddle", {name = peer_name, pad = pad, id = peer_id})
	
	# Force unload the game on shortcut press
	if is_playing:
		if Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game")
			return
		
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, JOY_START) and Input.is_joy_button_pressed(pad, JOY_SELECT):
				unload_game("You left the game")
				return
	
	# Pressing enter in the IP input "presses" join button
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		connect_to_server()
	
	# Pressing escape while viewing options returns to main menu
	if options_menu_node.visible and Input.is_action_just_released("ui_cancel"):
		toggle_menus(true)



##### HELPERS #####


# Set message text/visibility and timer
func set_message(new: String = "", time: int = 0) -> void:
	message_node.text = new
	if time > 0:
		message_timer.start(time)
	elif new != "" and not message_timer.is_stopped():
		message_timer.stop()


# Check if an input device is already used
func is_new_input(type: String, id: int) -> bool:
	for input in input_list.values():
		if type == "keys" and input.keys == id or type == "pad" and input.pad == id:
			return false
	return true


func crement(which: String, value: int) -> void:
	if which == "health":
		max_health = clamp(max_health + value, 1, 5)
	elif which == "balls":
		ball_count = clamp(ball_count + value, 1, 10)
	health_node.text = str(max_health)
	balls_node.text = str(ball_count)


func toggle_buttons(toggle: bool) -> void:
	name_input.editable = not toggle
	play_button.disabled = toggle
	ip_input.editable = not toggle
	join_button.disabled = toggle


func toggle_menus(to_main: bool) -> void:
	if not to_main:
		if get_name() == "":
			return
		start_button.grab_focus()
	else:
		play_button.grab_focus()
	
	main_menu_node.visible = to_main
	options_menu_node.visible = not to_main


func toggle_lan() -> void:
	is_open_to_lan = not is_open_to_lan


func toggle_small_map() -> void:
	using_small_map = not using_small_map


# Returns name from input, sending a message if invalid
func get_name() -> String:
	var new_name: String = name_input.text
	if new_name == "":
		set_message("Invalid name", 3)
	peer_name = new_name
	return new_name


func get_key(key1: int, key2: int, keys) -> int:
	return int(Input.is_key_pressed(key1 if keys == 0 else key2))


# Save configurables to file in JSON format
func save_config() -> void:
	var file: File = File.new()
	file.open("user://config.json", File.WRITE)
	var save: Dictionary = {
		name = name_input.text,
		ip = ip_input.text,
		is_open_to_lan = is_open_to_lan,
		using_small_map = using_small_map,
		health = max_health,
		balls = ball_count
	}
	file.store_line(to_json(save))
	file.close()


# Load configurables from JSON file if exists
func load_config() -> void:
	var file: File = File.new()
	if not file.file_exists("user://config.json"):
		return
	file.open("user://config.json", File.READ)
	var save: Dictionary = parse_json(file.get_line())
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
	crement("", 0)
	file.close()



##### CLIENT #####


# Attempt to join server
func connect_to_server() -> void:
	if get_name() == "":
		return
	var ip: String = ip_input.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_message("Invalid IP", 3)
			return
		ip = "127.0.0.1"
	set_message("Trying to connect...")
	toggle_buttons(true)
	initial_max_health = max_health
	var peer: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().network_peer = peer
	peer_id = get_tree().get_network_unique_id()
	join_timer.start(5)


# Unload paddle(s) from disconnected client
func peer_disconnected(id: int) -> void:
	var has_sent_msg: bool = false
	var paddles_to_clear: Array = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			if not has_sent_msg:
				set_message(paddle_data[paddle].name + " disconnected", 2)
				has_sent_msg = true
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_nodes.get_node(paddle).queue_free()
		bars_node.get_node(paddle).queue_free()
	bars_node.columns = clamp(paddle_data.size(), 1, 8)


# Client connects and sends version for checking
func connected() -> void:
	rpc_id(1, "check", peer_name, VERSION)


remote func check(name: String, version: String) -> void:
	var id: int = get_tree().get_rpc_sender_id()
	if version != VERSION:
		rpc_id(id, "unload_game", "Different server version (" + VERSION + ")")
		return
	set_message(name + " connected", 2)
	rpc_id(id, "load_game", paddle_data, using_small_map, map_node.modulate, max_health, ball_count)


# Send data to client to load game
remote func load_game(paddles: Dictionary, small_map: bool, map_color: Color, health: int, balls: int) -> void:
	save_config()
	max_health = health
	join_timer.stop()
	menu_node.hide()
	map_node.modulate = map_color
	if small_map:
		map_node.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_node.add_child(MAP_SCENE.instance())
	camera_spawn = map_node.get_child(0).get_node("CameraSpawn").position
	paddle_spawns = map_node.get_child(0).get_node("PaddleSpawns").get_children()
	ball_spawns = map_node.get_child(0).get_node("BallSpawns").get_children()
	for paddle in paddles:
		create_paddle(paddles[paddle])
	create_balls(balls)
	set_message("Press A/Enter to create your paddle", 5)
	is_playing = true
	camera_node.position = camera_spawn
	camera_node.current = true



##### GAME #####


func start_game() -> void:
	var peer: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().network_peer = peer
	get_tree().refuse_new_network_connections = not is_open_to_lan
	save_config()
	menu_node.hide()
	map_node.show()
	randomize()
	map_node.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	if using_small_map:
		map_node.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_node.add_child(MAP_SCENE.instance())
	camera_spawn = map_node.get_child(0).get_node("CameraSpawn").position
	paddle_spawns = map_node.get_child(0).get_node("PaddleSpawns").get_children()
	ball_spawns = map_node.get_child(0).get_node("BallSpawns").get_children()
	create_balls(ball_count)
	set_message("Press A/Enter to create your paddle", 5)
	is_playing = true
	camera_node.position = camera_spawn
	camera_node.current = true


remote func unload_game(msg: String = "") -> void:
	is_playing = false
	if get_tree().has_network_peer():
		if peer_id != 1:
			max_health = initial_max_health
		get_tree().set_deferred("network_peer", null)
		peer_id = 1
	join_timer.stop()
	set_message(msg, 3)
	input_list.clear()
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
	toggle_menus(true)
	camera_node.current = false
	play_button.grab_focus()
	toggle_buttons(false)


remotesync func update_objects(paddles: Dictionary, balls: Array) -> void:
	if not is_playing:
		return
	
	# Update data with nodes on server
	if peer_id == 1:
		for paddle in paddles:
			var paddle_node: KinematicBody2D = paddle_nodes.get_node(paddle)
			paddle_data[paddle].position = paddle_node.position
			paddle_data[paddle].rotation = paddle_node.rotation
			if paddles[paddle].id == peer_id:
				var input_data: Dictionary = get_inputs(paddle, input_list[paddle])
				inputs_to_paddle(paddle, input_data)
		for ball in ball_nodes.get_child_count():
			var ball_node: RigidBody2D = ball_nodes.get_child(ball)
			if ball_node.position.length() > 8192:
				ball_node.linear_velocity = Vector2()
				ball_node.angular_velocity = 0
				ball_node.position = ball_spawns[ball].position
				ball_node.rotation = 0
			ball_data[ball].position = ball_node.position
			ball_data[ball].rotation = ball_node.rotation
	
	# Update nodes with data from server
	else:
		for paddle in paddles:
			paddle_data[paddle].position = paddles[paddle].position
			paddle_data[paddle].rotation = paddles[paddle].rotation
			var paddle_node: Sprite = paddle_nodes.get_node(paddle)
			paddle_node.position = paddles[paddle].position
			paddle_node.rotation = paddles[paddle].rotation
			if paddles[paddle].id == peer_id:
				var input_data: Dictionary = get_inputs(paddle, input_list[paddle])
				rpc_unreliable_id(1, "inputs_to_paddle", paddle, input_data)
		for ball in ball_nodes.get_child_count():
			var ball_node: Sprite = ball_nodes.get_child(ball)
			ball_node.position = balls[ball].position
			ball_node.rotation = balls[ball].rotation



##### PADDLE #####


remote func create_paddle(data: Dictionary = {}) -> void:
	var paddle_count: int = paddle_nodes.get_child_count()
	var paddle_node: Node2D = PADDLE_SCENE.instance()
	
	# Change to client paddle if client
	if peer_id != 1:
		paddle_node = CLIENT_PADDLE_SCENE.instance()
	
	# Set position
	if data.has("position") and data.has("rotation"):
		paddle_node.position = data.position
		paddle_node.rotation = data.rotation
	else:
		paddle_node.position = paddle_spawns[paddle_count].position
		paddle_node.rotation = paddle_spawns[paddle_count].rotation
	
	# Set random (but unique) color
	if data.has("color"):
		paddle_node.modulate = data.color
	else:
		var used_colors: Array = [map_node.modulate]
		for paddle in paddle_data:
			used_colors.append(paddle_data[paddle].color)
		var new_color: Color = used_colors[0]
		while new_color in used_colors:
			randomize()
			new_color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
		paddle_node.modulate = new_color
	
	# Set name
	var name_count: int = 1
	for paddle in paddle_nodes.get_children():
		if data.name in paddle.name:
			name_count += 1
	var name_suffix: String = str(name_count) if name_count > 1 else ""
	paddle_node.name = data.name + name_suffix
	
	# Set input
	if peer_id == data.id:
		input_list[paddle_node.name] = {
			keys = data.keys if data.has("keys") else -1,
			pad = data.pad if data.has("pad") else -1
		}
	
	# Create HUD elements
	var bar: VBoxContainer = VBoxContainer.new()
	bar.name = paddle_node.name
	bar.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = paddle_node.modulate
	bar.alignment = BoxContainer.ALIGN_CENTER
	var label: Label = Label.new()
	label.text = paddle_node.name
	label.align = Label.ALIGN_CENTER
	bar.add_child(label)
	var hp_bar: HBoxContainer = HBoxContainer.new()
	hp_bar.name = paddle_node.name
	hp_bar.alignment = BoxContainer.ALIGN_CENTER
	hp_bar.set("custom_constants/separation", -18)
	for i in max_health:
		var bit: TextureRect = TextureRect.new()
		bit.texture = HP_TEXTURE
		if data.has("health"):
			bit.modulate.a = 1.0 if data.health > i else 0.1
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars_node.add_child(bar)
	bars_node.columns = clamp(bars_node.get_child_count(), 1, 8)
	
	paddle_data[paddle_node.name] = {
		position = paddle_node.position,
		rotation = paddle_node.rotation,
		spawn_position = paddle_node.position,
		spawn_rotation = paddle_node.rotation,
		name = paddle_node.name,
		id = data.id,
		color = paddle_node.modulate
	}
	
	paddle_data[paddle_node.name].health = data.health if data.has("health") else max_health
	
	# Send data to clients to create paddle
	if peer_id == 1 and is_open_to_lan:
		var new_data: Dictionary = paddle_data[paddle_node.name].duplicate(true)
		if data.id != peer_id:
			new_data.keys = data.keys if data.has("keys") else -1
			new_data.pad = data.pad if data.has("pad") else -1
		rpc("create_paddle", new_data)
	
	paddle_nodes.add_child(paddle_node)
	paddle_nodes.move_child(paddle_node, 0)


func get_inputs(paddle: String, input: Dictionary) -> Dictionary:
	if not OS.is_window_focused():
		return {velocity = Vector2(), rotation = 0, dash = false}
	
	var paddle_node: Node2D = paddle_nodes.get_node(paddle)
	var input_velocity: Vector2 = Vector2()
	var input_rotation: float = 0
	var dash: bool = false
	if input.keys >= 0:
		input_velocity.x = get_key(KEY_D, KEY_RIGHT, input.keys) - get_key(KEY_A, KEY_LEFT, input.keys)
		input_velocity.y = get_key(KEY_S, KEY_DOWN, input.keys) - get_key(KEY_W, KEY_UP, input.keys)
		input_velocity = input_velocity.normalized()
		if bool(get_key(KEY_SHIFT, KEY_KP_1, input.keys)):
			dash = true
		input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3, input.keys) - get_key(KEY_G, KEY_KP_2, input.keys)) * 4)
	if input.pad >= 0:
		var left_stick: Vector2 = Vector2(Input.get_joy_axis(input.pad, 0), Input.get_joy_axis(input.pad, 1))
		var right_stick: Vector2 = Vector2(Input.get_joy_axis(input.pad, 2), Input.get_joy_axis(input.pad, 3))
		if left_stick.length() > 0.2:
			input_velocity.x = sign(left_stick.x) * pow(left_stick.x, 2)
			input_velocity.y = sign(left_stick.y) * pow(left_stick.y, 2)
			if Input.is_joy_button_pressed(input.pad, JOY_L2):
				dash = true
		if right_stick.length() > 0.7:
			input_rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	
	return {velocity = input_velocity * MOVE_SPEED, rotation = input_rotation, dash = dash}


# Send client inputs to server-side paddle
remote func inputs_to_paddle(paddle: String, input: Dictionary) -> void:
	input.velocity = input.velocity.clamped(MOVE_SPEED)
	paddle_nodes.get_node(paddle).inputs(input)


remote func vibrate(paddle: String, is_destroyed: bool = false) -> void:
	if not is_playing:
		return
	
	if paddle_data[paddle].id == peer_id:
		if is_destroyed:
			Input.start_joy_vibration(input_list[paddle].pad, .2, .2, .3)
		else:
			Input.start_joy_vibration(input_list[paddle].pad, .1, 0, .1)
	
	elif peer_id == 1 and is_open_to_lan:
		rpc_id(paddle_data[paddle].id, "vibrate", paddle, is_destroyed)


# Manage paddle health
remote func hit(paddle: String) -> void:
	if peer_id == 1:
		rpc("hit", paddle)
	
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		if paddle_data[paddle].id == peer_id:
			vibrate(paddle, true)
		set_message(paddle_data[paddle].name + " was destroyed", 2)
		if peer_id == 1:
			paddle_nodes.get_node(paddle).position = paddle_data[paddle].spawn_position
			paddle_nodes.get_node(paddle).rotation = paddle_data[paddle].spawn_rotation
		paddle_data[paddle].health = max_health
	
	var health_bits: Array = bars_node.get_node(paddle).get_child(1).get_children()
	for i in max_health:
		health_bits[i].modulate.a = 1.0 if paddle_data[paddle].health > i else 0.1



##### BALL #####


func create_balls(count: int) -> void:
	for i in count:
		if i + 1 > ball_spawns.size():
			return
		
		var ball_node: Node2D = BALL_SCENE.instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball_node = CLIENT_BALL_SCENE.instance()
		ball_node.position = ball_spawns[i].position
		ball_node.name = str(i)
		ball_nodes.add_child(ball_node)
