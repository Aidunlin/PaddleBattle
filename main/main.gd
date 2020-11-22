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

enum State {IDLE, STARTING, PLAYING_LOCAL, PLAYING_LAN, ENDING}
var current_state = State.IDLE

var peer_id = 0
var client_pad = -1
var max_health = 3
var move_speed = 500
var ball_count = 10
var paddle_data = {}
var ball_data = []


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
	# Update balls over LAN
	if current_state == State.PLAYING_LAN and peer_id == 1:
		rpc_unreliable("update_paddles", paddle_data)
		rpc_unreliable("update_balls", ball_data)
	
	# Center camera to average paddle position, zoom camera to always view all paddles
	var zoom = Vector2(1, 1)
	if current_state != State.IDLE and paddle_nodes.get_child_count() > 0:
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
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		camera_node.position = avg
	camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.01 if camera_node.zoom > zoom else 0.1)

func _input(_event):
	# Create paddle if sensed input
	if current_state == State.STARTING and paddle_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			init_paddle(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			init_paddle(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 0) and is_new_pad(c):
					init_paddle(c)

	# Start game when paddle one presses start/enter
	if current_state == State.STARTING and paddle_data.size() > 1:
		if (paddle_data[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(paddle_data[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(paddle_data[0].pad >= 0 and Input.is_joy_button_pressed(paddle_data[0].pad, 0)):
			start_local_game()
	
	# Force unload the game on shortcut press
	if current_state in [State.PLAYING_LOCAL, State.PLAYING_LAN]:
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game!")
	
	# Pressing enter in the IP input "presses" join button
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		join_lan_game()
	
	# Switch input method when client is playing
	if current_state == State.PLAYING_LAN and peer_id != 1 and OS.is_window_focused():
		if client_pad == -1 and Input.is_joy_button_pressed(0, JOY_BUTTON_0):
			client_pad = 0
		elif client_pad == 0 and Input.is_key_pressed(KEY_ENTER):
			client_pad = -1


##### HELPERS #####

# Set message text/visibility and timer
func set_msg(msg = "", time = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()

# Check if a pad is already used
func is_new_pad(id):
	for paddle in paddle_data.values():
		if paddle.pad == id:
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
	var ip = ip_input.text
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
	set_msg("Player connected!", 2)
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
	set_msg("Player disconnected!", 2)
	if paddle_nodes.has_node(str(id)):
		paddle_nodes.get_node(str(id)).queue_free()
	paddle_data.erase(id)

# Client connects and sends data to host
func connected_to_server():
	join_timer.stop()
	set_msg("Connected!", 2)
	start_lan_game()

remote func data_to_clients(data):
	paddle_data = data
	for paddle in paddle_data:
		if not paddle_nodes.has_node(str(paddle)):
			init_paddle(paddle, paddle_data[paddle])


##### GAME #####

# Set up game, wait for paddles
func load_local_game():
	init_balls()
	current_state = State.STARTING
	set_msg("Press A/Enter to join (or begin if P1)")
	menu_node.hide()
	camera_node.position = camera_spawn

# Signal paddle nodes to begin
func start_local_game():
	set_msg()
	for p in paddle_data.values():
		p.node.enabled = true
	current_state = State.PLAYING_LOCAL

# Set up LAN game
func start_lan_game():
	menu_node.hide()
	current_state = State.PLAYING_LAN
	init_balls()

# Reset the game
func unload_game(msg = ""):
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


##### PADDLE #####

# Create paddle
func init_paddle(id, data = {}):
	var number = paddle_nodes.get_child_count()
	var paddle = load("res://paddle/paddle.tscn").instance()
	paddle.move_speed = move_speed
	paddle.position = paddle_spawns[number].position
	paddle.rotation = paddle_spawns[number].rotation
	
	# Local paddle
	if peer_id == 0:
		paddle.name = str(number)
		paddle.pad = id
		randomize()
		paddle.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
		
		# Add new HP bar for paddle
		var bar = HBoxContainer.new()
		bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
		bar.modulate = paddle.modulate
		bar.alignment = BoxContainer.ALIGN_CENTER
		var hp_bar = HBoxContainer.new()
		hp_bar.set("custom_constants/separation", -18)
		for _x in max_health:
			var bit = TextureRect.new()
			bit.texture = load("res://main/hp.png")
			hp_bar.add_child(bit)
		bar.add_child(hp_bar)
		bars.add_child(bar)
		bars.columns = clamp(bars.get_children().size(), 1, 4)
		
		# Add paddle node and data
		paddle.connect("hit", self, "paddle_hit")
		paddle_data[number] = {
			pad = id,
			health = max_health,
			color = paddle.modulate,
			hud = hp_bar,
			node = paddle
		}
	
	# LAN paddle
	else:
		if peer_id != 1:
			paddle = load("res://paddle/clientpaddle.tscn").instance()
			paddle.position = data.position
			paddle.rotation = data.rotation
		paddle.modulate = data.color
		paddle.name = str(id)
	paddle_nodes.add_child(paddle)
	paddle_nodes.move_child(paddle, 0)

# Update paddles on LAN
remotesync func update_paddles(data):
	if peer_id == 1:
		for paddle in data:
			var paddle_node = paddle_nodes.get_node(str(paddle))
			paddle_data[paddle].position = paddle_node.position
			paddle_data[paddle].rotation = paddle_node.rotation
	else:
		for paddle in data:
			var paddle_node = paddle_nodes.get_node(str(paddle))
			paddle_node.position = data[paddle].position
			paddle_node.rotation = data[paddle].rotation
		var input_data = get_client_inputs(peer_id)
		rpc_unreliable_id(1, "inputs_to_host", input_data)

# Collect client inputs for LAN
func get_client_inputs(p):
	var paddle = paddle_nodes.get_node(str(p))
	var input_velocity = Vector2()
	var input_rotation = 0
	if OS.is_window_focused() and client_pad < 0:
		input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
		input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
		input_velocity = input_velocity.normalized() * move_speed
		input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * 4)
	elif OS.is_window_focused():
		var l = Vector2(Input.get_joy_axis(client_pad, 0), Input.get_joy_axis(client_pad, 1))
		if l.length() > 0.2:
			input_velocity = Vector2(sign(l.x) * pow(l.x, 2), sign(l.y) * pow(l.y, 2)) * move_speed
		var r = Vector2(Input.get_joy_axis(client_pad, 2), Input.get_joy_axis(client_pad, 3))
		if r.length() > 0.7:
			input_rotation = paddle.get_angle_to(paddle.position + r) * 0.1
	return {velocity = input_velocity, rotation = input_rotation}

# Return keypress from either key based on pad
func get_key(key1, key2):
	return float(Input.is_key_pressed(key1) or Input.is_key_pressed(key2))

# Send client inputs to client's paddle host-side
remote func inputs_to_host(input_data):
	var id = get_tree().get_rpc_sender_id()
	paddle_nodes.get_node(str(id)).inputs_from_client(input_data)

# Vibrate client's controller if client paddle collides host-side
remote func vibrate():
	Input.start_joy_vibration(client_pad, 0.1, 0, 0.1)

# Manage paddle health
func paddle_hit(id):
	if current_state != State.PLAYING_LOCAL:
		return
	paddle_data[id].health -= 1
	if paddle_data[id].health == 0:
		if paddle_nodes.get_child_count() == 2:
			current_state = State.ENDING
			set_msg("Game ended!")
			end_timer.start(3)
		paddle_data[id].node.queue_free()
		Input.start_joy_vibration(paddle_data[id].pad, .2, .2, .3)
	var bits = paddle_data[id].hud.get_children()
	for i in max_health:
		bits[i].modulate.a = 1.0 if paddle_data[id].health > i else 0.1


##### BALL #####

# Create balls
func init_balls():
	for i in ball_count:
		var ball = load("res://ball/ball.tscn").instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball = load("res://ball/clientball.tscn").instance()
		ball.position = ball_spawns[i].position
		ball.name = str(i)
		ball_nodes.add_child(ball)

# Update balls on LAN
remotesync func update_balls(data):
	for i in ball_count:
		var ball = ball_nodes.get_child(i)
		if peer_id == 1:
			ball_data[i] = {
				position = ball.position,
				rotation = ball.rotation
			}
		else:
			ball.position = data[i].position
			ball.rotation = data[i].rotation
