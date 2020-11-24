extends Node

onready var map_node = $Map
onready var camera_spawn = $Map/CameraSpawn.position
onready var paddle_spawns = $Map/PaddleSpawns.get_children()
onready var ball_spawns = $Map/BallSpawns.get_children()
onready var camera_node = $Camera
onready var paddle_nodes = $Paddles
onready var ball_nodes = $Balls

onready var bars = $UI/HUD/Bars
onready var message_node = $UI/Message

onready var menu_node = $UI/Menu
onready var play_button = $UI/Menu/Main/Play
onready var name_input = $UI/Menu/Main/Name
onready var ip_input = $UI/Menu/Main/IP
onready var join_button = $UI/Menu/Main/Join

onready var join_timer = $JoinTimer
onready var message_timer = $MessageTimer

const hp_texture = preload("res://main/hp.png")
const paddle_scene = preload("res://paddle/paddle.tscn")
const client_paddle_scene = preload("res://paddle/clientpaddle.tscn")
const ball_scene = preload("res://ball/ball.tscn")
const client_ball_scene = preload("res://ball/clientball.tscn")

var playing: bool = false
var open_to_lan: bool = true
var peer_id: int = 1

var peer_name: String = ""
var paddle_data: Dictionary = {}
var ball_data: Array = []
var input_list: Dictionary = {}
var move_speed: int = 500
var max_health: int = 3
var ball_count: int = 10


func _ready():
	play_button.grab_focus()
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connected_to_server", self, "connected_to_server")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed!"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Host disconnected!"])
	randomize()
	map_node.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	camera_node.position = camera_spawn
	camera_node.current = true

func _physics_process(_delta):
	# Update objects over LAN
	if playing and open_to_lan and peer_id == 1:
		rpc_unreliable("update_objects", paddle_data, ball_data)
	
	# Modify camera to always show paddles
	var zoom: Vector2 = Vector2(1, 1)
	if playing and paddle_nodes.get_child_count() > 0:
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
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		camera_node.position = avg
	camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.01 if camera_node.zoom > zoom else 0.1)

func _input(_event):
	# Create paddle if sensed input
	if playing and OS.is_window_focused() and paddle_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and is_new_input("keys", 0):
			if peer_id == 1:
				init_paddle({name = peer_name, keys = 0, id = peer_id})
			else:
				rpc_id(1, "init_paddle", {name = peer_name, keys = 0, id = peer_id})
		if Input.is_key_pressed(KEY_KP_ENTER) and is_new_input("keys", 1):
			if peer_id == 1:
				init_paddle({name = peer_name, keys = 1, id = peer_id})
			else:
				rpc_id(1, "init_paddle", {name = peer_name, keys = 1, id = peer_id})
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and is_new_input("pad", pad):
				if peer_id == 1:
					init_paddle({name = peer_name, pad = pad, id = peer_id})
				else:
					rpc_id(1, "init_paddle", {name = peer_name, pad = pad, id = peer_id})
	
	# Force unload the game on shortcut press
	if playing and Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
		unload_game("You left the game!")
	
	# Pressing enter in the IP input "presses" join button
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		join_game()



##### HELPERS #####

# Set message text/visibility and timer
func set_msg(msg: String = "", time: int = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()

# Check if an input device is already used
func is_new_input(type: String, id: int):
	for input in input_list.values():
		if type == "keys" and input.keys == id or type == "pad" and input.pad == id:
			return false
	return true

# Toggles buttons... it's self-explanatory
func toggle_buttons(toggle: bool):
	play_button.disabled = toggle
	ip_input.editable = not toggle
	join_button.disabled = toggle

# Toggles open to lan... it's also self-explanatory
func toggle_lan():
	open_to_lan = not open_to_lan

# Returns name from input, sending a message if invalid
func get_name() -> String:
	var new_name: String = name_input.text
	if new_name == "":
		set_msg("Invalid name!", 3)
	peer_name = new_name
	return new_name


##### NETWORK #####

# Attempt to join LAN game
func join_game():
	if get_name() == "":
		return
	var ip: String = ip_input.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_msg("Invalid IP!", 3)
			return
		ip = "127.0.0.1"
	set_msg("Connecting...")
	toggle_buttons(true)
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().network_peer = peer
	peer_id = get_tree().get_network_unique_id()
	join_timer.start(5)

# Unload disconnected paddle(s)
func peer_disconnected(id):
	var sent_msg: bool = false
	var paddles_to_clear: Array = []
	for paddle in paddle_data:
		if paddle_data[paddle].id == id:
			if not sent_msg:
				set_msg(paddle_data[paddle].name + " disconnected!", 2)
				sent_msg = true
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		paddle_data.erase(paddle)
		paddle_nodes.get_node(paddle).queue_free()
		bars.get_node(paddle).queue_free()
	bars.columns = clamp(paddle_data.size(), 1, 8)

# Client connects and sends name
func connected_to_server():
	rpc_id(1, "check_client_name", peer_name)

# Host checks client name, kicking if it already exists
remote func check_client_name(client_name):
	var id: int = get_tree().get_rpc_sender_id()
	for paddle in paddle_data:
		if paddle_data[paddle].name == client_name:
			rpc_id(id, "kick", "Same name")
			return
	set_msg(client_name + " connected!", 2)
	rpc_id(id, "load_lan_game", paddle_data)

# Force client to unload
remote func kick(reason: String = ""):
	unload_game("You were kicked! " + reason)

# Send data to paddle
remote func load_lan_game(data: Dictionary):
	join_timer.stop()
	menu_node.hide()
	playing = true
	for paddle in data:
		init_paddle(data[paddle])
	init_balls()
	set_msg("Joined! Press A/Enter to create your paddle", 5)



##### GAME #####

func start_game():
	if get_name() == "":
		return
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().network_peer = peer
	get_tree().refuse_new_network_connections = not open_to_lan
	load_game()

# Set up game
remote func load_game():
	menu_node.hide()
	playing = true
	init_balls()
	set_msg("Press A/Enter to create your paddle", 5)

# Reset the game
func unload_game(msg: String = ""):
	playing = false
	if get_tree().has_network_peer():
		get_tree().set_deferred("network_peer", null)
		peer_id = 1
	join_timer.stop()
	set_msg(msg)
	if msg != "":
		message_timer.start(3)
	input_list.clear()
	for paddle in paddle_nodes.get_children():
		paddle.queue_free()
	paddle_data.clear()
	for ball in ball_nodes.get_children():
		ball.queue_free()
	ball_data.clear()
	for bar in bars.get_children():
		bar.queue_free()
	bars.columns = 1
	menu_node.show()
	camera_node.position = camera_spawn
	play_button.grab_focus()
	toggle_buttons(false)

# Update paddles and balls over LAN
remotesync func update_objects(paddles: Dictionary, balls: Array):
	# Update data with nodes on host
	if peer_id == 1:
		for paddle in paddles:
			var paddle_node = paddle_nodes.get_node(paddle)
			paddle_data[paddle].position = paddle_node.position
			paddle_data[paddle].rotation = paddle_node.rotation
		for ball in ball_count:
			var ball_node = ball_nodes.get_child(ball)
			ball_data[ball].position = ball_node.position
			ball_data[ball].rotation = ball_node.rotation
	
	# Update nodes with data from host
	else:
		for paddle in paddles:
			paddle_data[paddle].position = paddles[paddle].position
			paddle_data[paddle].rotation = paddles[paddle].rotation
			var paddle_node = paddle_nodes.get_node(paddle)
			paddle_node.position = paddles[paddle].position
			paddle_node.rotation = paddles[paddle].rotation
			if paddles[paddle].id == peer_id:
				var input_data: Dictionary = get_client_inputs(paddle, input_list[paddle])
				rpc_unreliable_id(1, "inputs_to_host", paddle, input_data)
		for ball in ball_count:
			var ball_node = ball_nodes.get_child(ball)
			ball_node.position = balls[ball].position
			ball_node.rotation = balls[ball].rotation



##### PADDLE #####

# Create paddle
remote func init_paddle(data: Dictionary = {}):
	var paddle_count: int = paddle_nodes.get_child_count()
	var paddle_node = paddle_scene.instance()
	paddle_node.move_speed = move_speed
	
	# Change to client paddle if client
	if peer_id != 1:
		paddle_node = client_paddle_scene.instance()
	
	# Set position
	if data.has("position") and data.has("rotation"):
		paddle_node.position = data.position
		paddle_node.rotation = data.rotation
	else:
		paddle_node.position = paddle_spawns[paddle_count].position
		paddle_node.rotation = paddle_spawns[paddle_count].rotation
	
	# Set color
	if data.has("color"):
		paddle_node.modulate = data.color
	else:
		randomize()
		paddle_node.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	
	# Set name
	var name_count: int = 0
	for paddle in paddle_nodes.get_children():
		if data.name in paddle.name:
			name_count += 1
	var name_suffix: String = str(name_count) if name_count > 0 else ""
	paddle_node.name = data.name + name_suffix
	
	# Set input
	if peer_id == data.id:
		input_list[paddle_node.name] = {
			keys = data.keys if data.has("keys") else -1,
			pad = data.pad if data.has("pad") else -1
		}
		if peer_id == 1:
			paddle_node.keys = input_list[paddle_node.name].keys
			paddle_node.pad = input_list[paddle_node.name].pad
			paddle_node.owned_by_server = true
	
	# Create HUD elements
	var bar = VBoxContainer.new()
	bar.name = paddle_node.name
	bar.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = paddle_node.modulate
	bar.alignment = BoxContainer.ALIGN_CENTER
	var label = Label.new()
	label.text = paddle_node.name
	label.align = Label.ALIGN_CENTER
	bar.add_child(label)
	var hp_bar = HBoxContainer.new()
	hp_bar.name = paddle_node.name
	hp_bar.alignment = BoxContainer.ALIGN_CENTER
	hp_bar.set("custom_constants/separation", -18)
	for _x in max_health:
		var bit = TextureRect.new()
		bit.texture = hp_texture
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars.add_child(bar)
	bars.columns = clamp(bars.get_child_count(), 1, 8)
	
	# Finalize data
	paddle_data[paddle_node.name] = {
		position = paddle_node.position,
		rotation = paddle_node.rotation,
		spawn_position = paddle_node.position,
		spawn_rotation = paddle_node.rotation,
		name = paddle_node.name,
		id = data.id,
		health = max_health,
		color = paddle_node.modulate
	}
	
	# Send data to client to create paddle
	if peer_id == 1 and open_to_lan:
		var new_data = paddle_data[paddle_node.name].duplicate(true)
		if data.id != peer_id:
			new_data.keys = data.keys if data.has("keys") else -1
			new_data.pad = data.pad if data.has("pad") else -1
		rpc("init_paddle", new_data)
	
	# Add paddle to tree
	paddle_nodes.add_child(paddle_node)
	paddle_nodes.move_child(paddle_node, 0)

# Collect client inputs for LAN
func get_client_inputs(paddle: String, input: Dictionary) -> Dictionary:
	var paddle_node = paddle_nodes.get_node(paddle)
	var input_velocity: Vector2 = Vector2()
	var input_rotation: float = 0
	if OS.is_window_focused():
		if input.keys >= 0:
			input_velocity.x = get_key(KEY_D, KEY_RIGHT, input.keys) - get_key(KEY_A, KEY_LEFT, input.keys)
			input_velocity.y = get_key(KEY_S, KEY_DOWN, input.keys) - get_key(KEY_W, KEY_UP, input.keys)
			input_velocity = input_velocity.normalized()
			input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3, input.keys) - get_key(KEY_G, KEY_KP_2, input.keys)) * 4)
		if input.pad >= 0:
			var left_stick: Vector2 = Vector2(Input.get_joy_axis(input.pad, 0), Input.get_joy_axis(input.pad, 1))
			var right_stick: Vector2 = Vector2(Input.get_joy_axis(input.pad, 2), Input.get_joy_axis(input.pad, 3))
			if left_stick.length() > 0.2:
				input_velocity.x = sign(left_stick.x) * pow(left_stick.x, 2)
				input_velocity.y = sign(left_stick.y) * pow(left_stick.y, 2)
			if right_stick.length() > 0.7:
				input_rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	return {velocity = input_velocity * move_speed, rotation = input_rotation}

# Return keypress from either key
func get_key(key1: int, key2: int, keys) -> int:
	return int(Input.is_key_pressed(key1 if keys == 0 else key2))

# Send client inputs to client's paddle host-side
remote func inputs_to_host(paddle: String, input_data: Dictionary):
	input_data.velocity = input_data.velocity.clamped(move_speed)
	paddle_nodes.get_node(paddle).inputs_from_client(input_data)

# Vibrate client's controller; called from host-side paddle
remote func vibrate(paddle: String, destroyed: bool = false):
	if destroyed:
		Input.start_joy_vibration(input_list[paddle].pad, .2, .2, .3)
	else:
		Input.start_joy_vibration(input_list[paddle].pad, 0.1, 0, 0.1)

# Manage paddle health
remote func paddle_hit(paddle: String):
	if peer_id == 1:
		rpc("paddle_hit", paddle)
	paddle_data[paddle].health -= 1
	if paddle_data[paddle].health < 1:
		if paddle_data[paddle].id == peer_id:
			vibrate(paddle, true)
		set_msg(paddle_data[paddle].name + " was destroyed!", 2)
		if peer_id == 1:
			paddle_nodes.get_node(paddle).position = paddle_data[paddle].spawn_position
			paddle_nodes.get_node(paddle).rotation = paddle_data[paddle].spawn_rotation
		paddle_data[paddle].health = max_health
	var health_bits = bars.get_node(paddle).get_node(paddle).get_children()
	for i in max_health:
		health_bits[i].modulate.a = 1.0 if paddle_data[paddle].health > i else 0.1



##### BALL #####

# Create balls
func init_balls():
	for i in ball_count:
		var ball_node = ball_scene.instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball_node = client_ball_scene.instance()
		ball_node.position = ball_spawns[i].position
		ball_node.name = str(i)
		ball_nodes.add_child(ball_node)
