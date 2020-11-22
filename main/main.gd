extends Node

onready var map_node = $Game/Map
onready var camera_spawn = $Game/Map/CameraSpawn.position
onready var player_spawns = $Game/Map/PlayerSpawns.get_children()
onready var ball_spawns = $Game/Map/BallSpawns.get_children()
onready var camera_node = $Game/Camera
onready var player_nodes = $Game/Players
onready var ball_nodes = $Game/Balls

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

var max_health = 3
var move_speed = 500
var ball_count = 10
var player_data = {}
var ball_data = []

var client_pad = -1


### BUILT-IN PROCESSES ###

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
	if current_state == State.PLAYING_LAN:
		if peer_id == 1:
			rpc_unreliable("update_players", player_data)
			rpc_unreliable("update_balls", ball_data)
	
	# Center camera to average player position, zoom camera to always view all players
	var zoom = Vector2(1, 1)
	if current_state != State.IDLE and player_nodes.get_child_count() > 0:
		var avg = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for player in player_nodes.get_children():
			avg += player.position
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		avg /= player_nodes.get_child_count()
		var zoom_x = (2 * max(max_x - avg.x, avg.x - min_x) + OS.window_size.x / 1.5) / OS.window_size.x
		var zoom_y = (2 * max(max_y - avg.y, avg.y - min_y) + OS.window_size.y / 1.5) / OS.window_size.y
		zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		camera_node.position = avg
	camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.01 if camera_node.zoom > zoom else 0.1)

func _input(_event):
	# Create player if sensed input
	if current_state == State.STARTING and player_data.size() < 8:
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_local_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_local_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 0) and is_new_pad(c):
					new_local_player(c)

	# Start game when player one presses start/enter
	if current_state == State.STARTING and player_data.size() > 1:
		if (player_data[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(player_data[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(player_data[0].pad >= 0 and Input.is_joy_button_pressed(player_data[0].pad, 0)):
			start_local_game()
	
	# Force unload the game on shortcut press
	if current_state in [State.PLAYING_LOCAL, State.PLAYING_LAN]:
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game!")
	
	# Pressing enter in the IP input "presses" join button
	if ip_input.has_focus() and Input.is_key_pressed(KEY_ENTER):
		join_lan_game()
	
	# Switch input method when client
	if current_state == State.PLAYING_LAN and peer_id != 1:
		if OS.is_window_focused():
			if client_pad == -1 and Input.is_joy_button_pressed(0, JOY_BUTTON_0):
				client_pad = 0
			elif client_pad == 0 and Input.is_key_pressed(KEY_ENTER):
				client_pad = -1


### HELPER FUNCTIONS ###

# Set message text/visibility and timer
func set_msg(msg = "", time = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()

# Check if a pad is already used
func is_new_pad(id):
	for player in player_data.values():
		if player.pad == id:
			return false
	return true


### NETWORK MANAGEMENT ###

# Begin hosting LAN game
func host_lan_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().set_network_peer(peer)
	peer_id = 1
	player_data[1] = {
		position = camera_spawn,
		rotation = 0,
		color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	}
	set_msg("Hosting game!", 2)
	new_lan_player(1, player_data[1])
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
		player_data[id] = {
			position = camera_spawn,
			rotation = 0,
			color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
		}
		new_lan_player(id, player_data[id])
		rpc("data_to_clients", player_data)

# Clear the disconnected peer's data
func peer_disconnected(id):
	set_msg("Player disconnected!", 2)
	if player_nodes.has_node(str(id)):
		player_nodes.get_node(str(id)).queue_free()
	player_data.erase(id)

# Client connects and sends data to host
func connected_to_server():
	join_timer.stop()
	set_msg("Connected!", 2)
	start_lan_game()

remote func data_to_clients(data):
	player_data = data
	for player in player_data:
		if not player_nodes.has_node(str(player)):
			new_lan_player(player, player_data[player])

### GAME MANAGEMENT ###

# Set up game, wait for players
func load_local_game():
	init_balls()
	current_state = State.STARTING
	set_msg("Press A/Enter to join (or begin if P1)")
	menu_node.hide()
	camera_node.position = camera_spawn

# Signal player nodes to begin
func start_local_game():
	set_msg()
	for p in player_data.values():
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
	for player in player_nodes.get_children():
		player.queue_free()
	player_data.clear()
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


### PLAYER MANAGEMENT ###

# Create local player with gamepad id
func new_local_player(id):
	# Create player node and color
	var number = player_data.size()
	var player = load("res://player/player.tscn").instance()
	player.name = str(number)
	player.pad = id
	player.move_speed = move_speed
	randomize()
	player.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	
	# Add new HP bar for player
	var bar = HBoxContainer.new()
	bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = player.modulate
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
	
	# Add player node and data
	player.position = player_spawns[number].position
	player.rotation = player_spawns[number].rotation
	player.connect("hit", self, "player_hit")
	player_data[number] = {
		pad = id,
		health = max_health,
		color = bar.modulate,
		hud = hp_bar,
		node = player
	}
	player_nodes.add_child(player)
	player_nodes.move_child(player, 0)

# Create lan player with network id and data 
func new_lan_player(id, data):
	var player = load("res://player/player.tscn").instance()
	if peer_id == 1:
		player.move_speed = move_speed
	else:
		player = load("res://player/clientplayer.tscn").instance()
	player.name = str(id)
	player.modulate = data.color
	player.position = data.position
	player.rotation = data.rotation
	player_nodes.add_child(player)
	player_nodes.move_child(player, 0)

# Update players on LAN
remotesync func update_players(data):
	if peer_id == 1:
		for player in data:
			var player_node = player_nodes.get_node(str(player))
			player_data[player].position = player_node.position
			player_data[player].rotation = player_node.rotation
	else:
		for player in data:
			var player_node = player_nodes.get_node(str(player))
			player_node.position = data[player].position
			player_node.rotation = data[player].rotation
		var input_data = get_client_inputs(peer_id)
		rpc_unreliable_id(1, "inputs_to_host", input_data)

# Collect client inputs for LAN
func get_client_inputs(p):
	var player = player_nodes.get_node(str(p))
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
			input_rotation = player.get_angle_to(player.position + r) * 0.1
	return {velocity = input_velocity, rotation = input_rotation}

# Return keypress from either key based on pad
func get_key(key1, key2):
	return float(Input.is_key_pressed(key1) or Input.is_key_pressed(key2))

remote func inputs_to_host(input_data):
	var id = get_tree().get_rpc_sender_id()
	player_nodes.get_node(str(id)).inputs_from_client(input_data)

# Manage player health
func player_hit(id):
	if current_state != State.PLAYING_LOCAL:
		return
	player_data[id].health -= 1
	if player_data[id].health == 0:
		if player_nodes.get_child_count() == 2:
			current_state = State.ENDING
			set_msg("Game ended!", 3)
		player_data[id].node.queue_free()
		Input.start_joy_vibration(player_data[id].pad, .2, .2, .3)
	var bits = player_data[id].hud.get_children()
	for i in max_health:
		bits[i].modulate.a = 1.0 if player_data[id].health > i else 0.1


### BALL CODE ###

# Create balls
func init_balls():
	for i in ball_count:
		var ball = load("res://ball/ball.tscn").instance()
		if get_tree().network_peer:
			if peer_id == 1:
				ball_data.append({})
			else:
				ball = load("res://ball/clientball.tscn").instance()
		ball.name = str(i)
		ball.position = ball_spawns[i].position
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
