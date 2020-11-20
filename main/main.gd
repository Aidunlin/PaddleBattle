extends Node

onready var map_node = $Game/Map
onready var camera_spawn = $Game/Map/CameraSpawn.position
onready var player_spawns = $Game/Map/PlayerSpawns
onready var ball_spawns = $Game/Map/BallSpawns
onready var camera_node = $Game/Camera
onready var player_nodes = $Game/Players
onready var ball_nodes = $Game/Balls

onready var bars = $UI/HUD/Bars
onready var msg_panel = $UI/Msg
onready var msg_node = $UI/Msg/Panel/Message

onready var menu_node = $UI/Menu
onready var play_btn = $UI/Menu/Panel/Main/Play
onready var host_btn = $UI/Menu/Panel/Main/Host
onready var ip_input = $UI/Menu/Panel/Main/JoinBar/IP
onready var join_btn = $UI/Menu/Panel/Main/JoinBar/Join
onready var quit_btn = $UI/Menu/Panel/Main/Quit

onready var join_timer = $JoinTimer
onready var end_timer = $EndTimer
onready var msg_timer = $MsgTimer

var network_id = 0
var state = "idle"
var health = 3
var balls = 10
var player_data = {}
var ball_data = []


### BUILT-IN PROCESSES ###

func _ready():
	play_btn.grab_focus()
	quit_btn.connect("pressed", get_tree(), "quit")
	
	get_tree().connect("network_peer_connected", self, "peer_connected")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connected_to_server", self, "connected_to_server")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed!"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Host disconnected!"])

	randomize()
	map_node.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	camera_node.position = camera_spawn

func _physics_process(_delta):
	# Update balls over LAN
	if state == "lan":
		if get_tree().is_network_server():
			rpc_unreliable("update_balls", ball_data)
	
	# Center camera to average player position, zoom camera to always view all players
	if state != "idle" and player_nodes.get_child_count() > 0:
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
		var zoom_x = (max(max_x - avg.x, avg.x - min_x) * 2 + 500) / OS.window_size.x
		var zoom_y = (max(max_y - avg.y, avg.y - min_y) * 2 + 500) / OS.window_size.y
		var zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		camera_node.position = avg
		camera_node.zoom = camera_node.zoom.linear_interpolate(zoom, 0.05)

func _input(_event):
	# Create player if sensed input
	if player_data.size() < 8 and state == "starting":
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_local_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_local_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 0) and is_new_pad(c):
					new_local_player(c)

	# Start game when player one presses start/enter
	if state == "starting" and player_data.size() > 1:
		if (player_data[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(player_data[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(player_data[0].pad >= 0 and Input.is_joy_button_pressed(player_data[0].pad, 0)):
			start_local_game()
	
	# Force unload the game on shortcut press
	if ["lan", "playing", "state"].has(state):
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("You left the game!")


### HELPER FUNCTIONS ###

# Set message text/visibility and timer
func set_msg(msg = ""):
	msg_node.text = msg
	msg_panel.visible = msg != ""
	if msg != "" and not msg_timer.is_stopped():
		msg_timer.stop()

# Check if a pad is already used
func is_new_pad(id):
	for player in player_data.values():
		if player.pad == id:
			return false
	return true


### NETWORKING CODE ###

# Begin hosting LAN game
func host_lan_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().set_network_peer(peer)
	network_id = get_tree().get_network_unique_id()
	player_data[network_id] = {position = camera_spawn, rotation = 0,
		color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)}
	load_lan_game()

# Attempt to join LAN game
func join_lan_game():
	var ip = ip_input.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_msg("Invalid IP!")
			msg_timer.start(3)
			return
		ip = "127.0.0.1"
	set_msg("Connecting...")
	play_btn.disabled = true
	host_btn.disabled = true
	ip_input.editable = false
	join_btn.disabled = true
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().set_network_peer(peer)
	join_timer.start(5)

# Each client requests data of new client
func peer_connected(id):
	set_msg("Player joined!")
	msg_timer.start(2)
	if not get_tree().is_network_server():
		rpc_id(1, "request_data", network_id, id)

# Clear the disconnected peer's data
func peer_disconnected(id):
	set_msg("Player disconnected!")
	msg_timer.start(2)
	if player_nodes.has_node(str(id)):
		player_nodes.get_node(str(id)).queue_free()
	player_data.erase(id)

# Client loads game and sends their data to everyone
func connected_to_server():
	network_id = get_tree().get_network_unique_id()
	join_timer.stop()
	player_data[network_id] = {position = camera_spawn, rotation = 0,
				 color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)}
	load_lan_game()
	rpc("send_data", network_id, player_data[network_id])

# Host sends specific client data to requesting client
remote func request_data(from_id, peer_id):
	if get_tree().is_network_server():
		rpc_id(from_id, "send_data", peer_id, player_data[peer_id])

# Requesting client receives specific data
remote func send_data(id, data):
	player_data[id] = data
	new_lan_player(id, data)


### GAME MANAGEMENT ###

# Set up game, wait for players
func load_local_game():
	init_balls()
	state = "starting"
	set_msg("Press A/Enter to join (or begin if P1)")
	menu_node.hide()
	camera_node.position = camera_spawn

# Signal player nodes to begin
func start_local_game():
	set_msg()
	for p in player_data.values():
		p.node.enabled = true
	state = "playing"

# Set up LAN game
func load_lan_game():
	set_msg()
	menu_node.hide()
	new_lan_player(network_id, player_data[network_id])
	state = "lan"
	init_balls()

# Reset the game
func unload_game(msg = ""):
	join_timer.stop()
	set_msg(msg)
	if msg != "":
		msg_timer.start(3)
	state = "idle"
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
	camera_node.zoom = Vector2(1, 1)
	if get_tree().has_network_peer():
		get_tree().set_deferred("network_peer", null)
		network_id = 0
	play_btn.grab_focus()
	play_btn.disabled = false
	host_btn.disabled = false
	ip_input.editable = true
	join_btn.disabled = false


### PLAYER MANAGEMENT ###

# Create local player with gamepad id
func new_local_player(id):
	# Create player node and color
	var number = player_data.size()
	var player = load("res://player/player.tscn").instance()
	player.name = str(number)
	player.pad = id
	randomize()
	player.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	
	# Add new HP bar for player
	var bar = HBoxContainer.new()
	bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = player.modulate
	bar.alignment = BoxContainer.ALIGN_CENTER
	var hp_bar = HBoxContainer.new()
	hp_bar.set("custom_constants/separation", -18)
	for _x in health:
		var bit = TextureRect.new()
		bit.texture = load("res://main/hp.png")
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars.add_child(bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	# Add player node and data
	player.spawn_position = player_spawns.get_child(number).position
	player.spawn_rotation = player_spawns.get_child(number).rotation
	player.connect("hit", self, "player_hit")
	player_data[number] = {pad=id, hp=health, color=bar.modulate, hud=hp_bar, node=player}
	player_nodes.add_child(player)
	player_nodes.move_child(player, 0)

# Create lan player with network id and data 
func new_lan_player(id, data):
	var player = load("res://player/player.tscn").instance()
	player.name = str(id)
	player.playing_lan = true
	player.set_network_master(id)
	player.modulate = data.color
	player.connect("update", self, "update_player")
	player.position = data.position
	player.rotation = data.rotation
	player.spawn_position = data.position
	player.spawn_rotation = data.rotation
	player_nodes.add_child(player)
	player_nodes.move_child(player, 0)

# Update lan player data
func update_player(id, position, rotation):
	if state == "lan":
		player_data[id].position = position
		player_data[id].rotation = rotation

# Manage player health
func player_hit(id):
	if state != "playing":
		return
	player_data[id].hp -= 1
	if player_data[id].hp == 0:
		if player_nodes.get_child_count() == 2:
			state = "ending"
			set_msg("Game ended!")
			end_timer.start(3)
		player_data[id].node.queue_free()
		Input.start_joy_vibration(player_data[id].pad, .2, .2, .3)
	var bits = player_data[id].hud.get_children()
	for i in health:
		bits[i].modulate.a = 1.0 if player_data[id].hp > i else 0.1


### BALL CODE ###

# Create balls
func init_balls():
	for i in balls:
		var ball = load("res://ball/ball.tscn").instance()
		if get_tree().network_peer:
			if get_tree().is_network_server():
				ball_data.append({position = ball.position, rotation = ball.rotation})
			else:
				ball = load("res://ball/fakeball.tscn").instance()
		ball.position = ball_spawns.get_child(i).position
		ball_nodes.add_child(ball)

# Update balls on LAN
remotesync func update_balls(data):
	for i in balls:
		if get_tree().is_network_server():
			ball_data[i].position = ball_nodes.get_child(i).position
			ball_data[i].rotation = ball_nodes.get_child(i).rotation
		else:
			ball_nodes.get_child(i).position = data[i].position
			ball_nodes.get_child(i).rotation = data[i].rotation
