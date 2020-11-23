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
onready var host_button = $UI/Menu/Main/Host
onready var ip_input = $UI/Menu/Main/JoinBar/IP
onready var join_button = $UI/Menu/Main/JoinBar/Join

onready var join_timer = $JoinTimer
onready var end_timer = $EndTimer
onready var message_timer = $MessageTimer

const hp_texture = preload("res://main/hp.png")
const paddle_scene = preload("res://paddle/paddle.tscn")
const client_paddle_scene = preload("res://paddle/clientpaddle.tscn")
const ball_scene = preload("res://ball/ball.tscn")
const client_ball_scene = preload("res://ball/clientball.tscn")

enum State {IDLE, PLAYING_LOCAL, PLAYING_LAN}
var current_state: int = State.IDLE

var peer_id: int = 0
var max_health: int = 3
var move_speed: int = 500
var ball_count: int = 10
var paddle_data: Dictionary = {}
var ball_data: Array = []


func _ready():
	play_button.grab_focus()
	get_tree().connect("network_peer_connected", self, "peer_connected")
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
	if current_state == State.PLAYING_LAN and peer_id == 1:
		rpc_unreliable("update_objects", paddle_data, ball_data)
	
	# Center camera to average paddle position, and
	# Zoom camera to always view all paddles
	var zoom: Vector2 = Vector2(1, 1)
	if current_state != State.IDLE and paddle_nodes.get_child_count() > 0:
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
	if current_state == State.PLAYING_LOCAL and paddle_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and is_new_input("keys", 0):
			init_paddle(paddle_data.size(), {keys = 0})
		if Input.is_key_pressed(KEY_KP_ENTER) and is_new_input("keys", 1):
			init_paddle(paddle_data.size(), {keys = 1})
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, 0) and is_new_input("pad", pad):
				init_paddle(paddle_data.size(), {pad = pad})
	
	# Force unload the game on shortcut press
	if current_state in [State.PLAYING_LOCAL, State.PLAYING_LAN]:
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game!")
	
	# Pressing enter in the IP input "presses" join button
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		join_lan_game()



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
	for paddle in paddle_data.values():
		if type == "keys" and paddle.keys == id or type == "pad" and paddle.pad == id:
			return false
	return true



##### NETWORK #####

# Begin hosting LAN game
func host_lan_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().set_network_peer(peer)
	peer_id = 1
	paddle_data[1] = {
		position = Vector2(),
		rotation = 0,
		color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	}
	init_paddle(1, paddle_data[1])
	start_lan_game()

# Attempt to join LAN game
func join_lan_game():
	var ip: String = ip_input.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_msg("Invalid IP!")
			message_timer.start(3)
			return
		ip = "127.0.0.1"
	set_msg("Connecting...")
	play_button.disabled = true
	host_button.disabled = true
	ip_input.editable = false
	join_button.disabled = true
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().set_network_peer(peer)
	peer_id = get_tree().get_network_unique_id()
	join_timer.start(5)

# Send data to new peer
func peer_connected(id):
	set_msg("Paddle connected!", 2)
	if peer_id == 1:
		paddle_data[id] = {
			position = Vector2(),
			rotation = 0,
			color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
		}
		init_paddle(id, paddle_data[id])
		rpc("data_to_clients", paddle_data)

# Clear the disconnected peer's data
func peer_disconnected(id):
	set_msg("Paddle disconnected!", 2)
	if paddle_nodes.has_node(str(id)):
		paddle_nodes.get_node(str(id)).queue_free()
	paddle_data.erase(id)

# Client connects
func connected_to_server():
	join_timer.stop()
	set_msg("Connected!", 2)
	start_lan_game()

# Update paddle data to all connected peers
remote func data_to_clients(data: Dictionary):
	paddle_data = data
	for paddle in paddle_data:
		if not paddle_nodes.has_node(str(paddle)):
			init_paddle(paddle, paddle_data[paddle])



##### GAME #####

# Set up game, wait for paddles
func start_local_game():
	current_state = State.PLAYING_LOCAL
	init_balls()
	set_msg("Press A/Enter to join", 5)
	menu_node.hide()

# Set up LAN game
func start_lan_game():
	menu_node.hide()
	current_state = State.PLAYING_LAN
	init_balls()

# Reset the game
func unload_game(msg: String = ""):
	join_timer.stop()
	set_msg(msg)
	if msg != "":
		message_timer.start(3)
	current_state = State.IDLE
	end_timer.stop()
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
	if get_tree().has_network_peer():
		get_tree().set_deferred("network_peer", null)
		peer_id = 0
	play_button.grab_focus()
	play_button.disabled = false
	host_button.disabled = false
	ip_input.editable = true
	join_button.disabled = false

# Update paddles and balls over LAN
remotesync func update_objects(paddles: Dictionary, balls: Array):
	if peer_id == 1:
		for paddle in paddles:
			var paddle_node = paddle_nodes.get_node(str(paddle))
			paddle_data[paddle].position = paddle_node.position
			paddle_data[paddle].rotation = paddle_node.rotation
		
		for ball in ball_count:
			var ball_node = ball_nodes.get_child(ball)
			ball_data[ball].position = ball_node.position
			ball_data[ball].rotation = ball_node.rotation
	
	else:
		for paddle in paddles:
			var paddle_node = paddle_nodes.get_node(str(paddle))
			paddle_node.position = paddles[paddle].position
			paddle_node.rotation = paddles[paddle].rotation
		
		for ball in ball_count:
			var ball_node = ball_nodes.get_child(ball)
			ball_node.position = balls[ball].position
			ball_node.rotation = balls[ball].rotation
		
		var input_data = get_client_inputs(peer_id)
		rpc_unreliable_id(1, "inputs_to_host", input_data)



##### PADDLE #####

# Create paddle
func init_paddle(id: int, data: Dictionary = {}):
	var number: int = paddle_nodes.get_child_count()
	var paddle_node = paddle_scene.instance()
	paddle_node.move_speed = move_speed
	paddle_node.position = paddle_spawns[number].position
	paddle_node.rotation = paddle_spawns[number].rotation
	
	# Local paddle
	if peer_id == 0:
		paddle_node.name = str(number)
		randomize()
		paddle_node.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
		
		paddle_data[number] = {
			health = max_health,
			color = paddle_node.modulate,
			node = paddle_node
		}
		if data.has("keys"):
			paddle_node.keys = data.keys
		if data.has("pad"):
			paddle_node.pad = data.pad
		paddle_data[number].keys = paddle_node.keys
		paddle_data[number].pad = paddle_node.pad
		
		# Add new HP bar for paddle
		var bar = HBoxContainer.new()
		bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
		bar.modulate = paddle_node.modulate
		bar.alignment = BoxContainer.ALIGN_CENTER
		var hp_bar = HBoxContainer.new()
		hp_bar.set("custom_constants/separation", -18)
		for _x in max_health:
			var bit = TextureRect.new()
			bit.texture = hp_texture
			hp_bar.add_child(bit)
		bar.add_child(hp_bar)
		bars.add_child(bar)
		bars.columns = clamp(bars.get_children().size(), 1, 4)
		paddle_data[number].hud = hp_bar
		
		# Add paddle node and data
		paddle_node.connect("hit", self, "paddle_hit")
	
	# LAN paddle
	else:
		if peer_id != 1:
			paddle_node = client_paddle_scene.instance()
			paddle_node.position = data.position
			paddle_node.rotation = data.rotation
		paddle_node.modulate = data.color
		paddle_node.name = str(id)
	paddle_nodes.add_child(paddle_node)
	paddle_nodes.move_child(paddle_node, 0)

# Collect client inputs for LAN
func get_client_inputs(id: int):
	var paddle_node = paddle_nodes.get_node(str(id))
	var input_velocity: Vector2 = Vector2()
	var input_rotation: float = 0
	if OS.is_window_focused():
		input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
		input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
		input_velocity = input_velocity.normalized() * move_speed
		input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * 4)
		
		var left_stick: Vector2 = Vector2(Input.get_joy_axis(0, 0), Input.get_joy_axis(0, 1))
		if left_stick.length() > 0.2:
			input_velocity.y = sign(left_stick.y) * pow(left_stick.y, 2)
			input_velocity.x = sign(left_stick.x) * pow(left_stick.x, 2)
			input_velocity *= move_speed
		var right_stick: Vector2 = Vector2(Input.get_joy_axis(0, 2), Input.get_joy_axis(0, 3))
		if right_stick.length() > 0.7:
			input_rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	
	return {velocity = input_velocity, rotation = input_rotation}

# Return keypress from either key based on pad
func get_key(key1: int, key2: int):
	return float(Input.is_key_pressed(key1) or Input.is_key_pressed(key2))

# Send client inputs to client's paddle host-side
remote func inputs_to_host(input_data: Dictionary):
	var id: int = get_tree().get_rpc_sender_id()
	input_data.velocity = input_data.velocity.clamped(move_speed)
	paddle_nodes.get_node(str(id)).inputs_from_client(input_data)

# Vibrate client's controller if client paddle collides host-side
remote func vibrate():
	Input.start_joy_vibration(0, 0.1, 0, 0.1)

# Manage paddle health
func paddle_hit(id: int):
	if current_state != State.PLAYING_LOCAL:
		return
	paddle_data[id].health -= 1
	var bits = paddle_data[id].hud.get_children()
	for i in max_health:
		bits[i].modulate.a = 1.0 if paddle_data[id].health > i else 0.1
	if paddle_data[id].health == 0:
		Input.start_joy_vibration(paddle_data[id].pad, .2, .2, .3)
		set_msg("Paddle died!")
		message_timer.start(2)
		paddle_data[id].node.position = paddle_spawns[id].position
		paddle_data[id].node.rotation = paddle_spawns[id].rotation
		paddle_data[id].health = max_health
		for i in max_health:
			bits[i].modulate.a = 1.0



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
