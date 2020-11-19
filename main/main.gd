extends Node

onready var camera_spawn = $Game/TestMap/CameraSpawn.position
onready var spawns = $Game/TestMap/PlayerSpawns
onready var bars = $UI/HUD/Bars
onready var address = $UI/Menu/Panel/Main/Options/LAN/Join/IP

var menu = "UI/Menu/Panel/Main/"
var menu_local = menu + "Options/Local/"
var menu_lan = menu + "Options/LAN/"

var state = "idle"
var health = 3
var balls = 10
var player_data = []
var ending_timer = Timer.new()

var playing = false
var ball_data = []
onready var self_data = {position=$Game/TestMap/CameraSpawn.position, rotation=0}

func _ready():
	get_node(menu_local + "Health/Dec").connect("pressed", self, "crement", ["hp", -1])
	get_node(menu_local + "Health/Inc").connect("pressed", self, "crement", ["hp", 1])
	get_node(menu_local + "Balls/Dec").connect("pressed", self, "crement", ["balls", -1])
	get_node(menu_local + "Balls/Inc").connect("pressed", self, "crement", ["balls", 1])
	get_node(menu_local + "Play").grab_focus()
	get_node(menu_local + "Play").connect("pressed", self, "load_game")
	get_node(menu_lan + "Host").connect("pressed", self, "host_game")
	get_node(menu_lan + "Join/Join").connect("pressed", self, "join_game")
	get_node(menu_lan + "Quit").connect("pressed", get_tree(), "quit")
	
	get_tree().connect("network_peer_connected", self, "peer_connected")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed!"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected!"])
	
	add_child(ending_timer)
	ending_timer.connect("timeout", self, "unload_game", [""])
	randomize()
	$Game/TestMap.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	$Game/Camera.position = camera_spawn

func _process(_delta):
	# Center camera to average player position, zoom camera to always view all players
	if state != "idle" and $Game/Players.get_child_count() > 0:
		var avg = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for player in $Game/Players.get_children():
			avg.x += player.position.x
			avg.y += player.position.y
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		avg /= $Game/Players.get_child_count()
		var zoom_x = (max(max_x - avg.x, avg.x - min_x) * 2 + 500) / OS.window_size.x
		var zoom_y = (max(max_y - avg.y, avg.y - min_y) * 2 + 500) / OS.window_size.y
		var zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		$Game/Camera.position = avg
		$Game/Camera.zoom = $Game/Camera.zoom.linear_interpolate(zoom, 0.05)
	
	# Center camera on player when playing over LAN
	if playing:
		$Game/Camera.position = self_data.position
		if get_tree().is_network_server():
			rpc_unreliable("update_balls", ball_data)

func _input(_event):
	# Create player if sensed input
	if player_data.size() < 8 and state == "starting":
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 0) and is_new_pad(c):
					new_player(c)

	# Start game when player one presses start/enter
	if state == "starting" and player_data.size() > 1:
		if (player_data[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(player_data[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(player_data[0].pad >= 0 and Input.is_joy_button_pressed(player_data[0].pad, 0)):
			start_game()
	
	# Force unload the game on shortcut press
	if playing or state == "playing" or state == "starting":
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("")

# Begin hosting LAN game
func host_game():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 7)
	get_tree().set_network_peer(peer)
	player_data[1] = self_data
	load_game()

# Attempt to join LAN game
func join_game():
	var ip = address.text
	if not ip.is_valid_ip_address():
		if ip != "":
			set_msg("Invalid IP!")
			return
		ip = "127.0.0.1"
	set_msg("Connecting...")
	get_node(menu_lan + "Host").disabled = true
	get_node(menu + "Join/Join").disabled = true
	get_tree().connect("connected_to_server", self, "connected_to_server")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, 8910)
	get_tree().set_network_peer(peer)

# Basic network funcs

func peer_connected(id):
	if not get_tree().is_network_server():
		rpc_id(1, "request_data", get_tree().get_network_unique_id(), id)

func peer_disconnected(id):
	if $Game/Players.has_node(str(id)):
		$Game/Players.get_node(str(id)).queue_free()
	player_data.erase(id)

func connected_to_server():
	load_game()
	player_data[get_tree().get_network_unique_id()] = self_data
	rpc("send_data", get_tree().get_network_unique_id(), self_data)

# Initial request/send when joining

remote func request_data(from_id, peer_id):
	if get_tree().is_network_server():
		rpc_id(from_id, "send_data", peer_id, player_data[peer_id])

remote func send_data(id, data):
	player_data[id] = data
	init_player(id, data)

# Create balls
func init_balls():
	for i in balls:
		var ball = load("res://ball/ball.tscn").instance()
		if get_tree().has_network_peer() and not get_tree().is_network_server():
			ball = load("res://online/ball.tscn").instance()
		else:
			if get_tree().is_network_server():
				ball_data.append({position = ball.position, rotation = ball.rotation})
			ball.position = $Game/TestMap/BallSpawns.get_child(i).position
		$Game/Balls.add_child(ball)

# Update balls on LAN
remotesync func update_balls(data):
	for i in balls:
		if get_tree().is_network_server():
			ball_data[i].position = $Game/Balls.get_child(i).position
			ball_data[i].rotation = $Game/Balls.get_child(i).rotation
		else:
			$Game/Balls.get_child(i).position = data[i].position
			$Game/Balls.get_child(i).rotation = data[i].rotation

# Set up game, wait for players
func load_game():
	state = "starting"
	set_msg("Press A/Enter to join (or begin if P1)")
	$UI/Menu.hide()
	$Game/Camera.position = camera_spawn

# Signal player nodes to begin
func start_game():
	set_msg("")
	for p in player_data:
		p.node.is_enabled = true
	state = "playing"

# Reset and clear players/balls
func unload_game(msg):
	set_msg(msg)
	state = "idle"
	ending_timer.stop()
	$Game/Camera.position = camera_spawn
	$Game/Camera.zoom = Vector2(1, 1)
	for player in $Game/Players.get_children():
		player.queue_free()
	player_data.clear()
	for ball in $Game/Balls.get_children():
		ball.queue_free()
	ball_data.clear()
	for bar in bars.get_children():
		bar.queue_free()
	bars.columns = 1
	$UI/Menu.show()
	get_node(menu_local + "Play").grab_focus()

# Create new player
func new_player(id):
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
	for _x in range(health):
		var bit = TextureRect.new()
		bit.texture = load("res://main/hp.png")
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bars.add_child(bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	# Add player node and data
	player.spawn_position = spawns.get_child(number).position
	player.spawn_rotation = spawns.get_child(number).rotation
	player.connect("hit", self, "on_player_hit")
	player_data.append({pad=id, hp=health, color=bar.modulate, hud=hp_bar, node=player})
	$Game/Players.add_child(player)
	$Game/Players.move_child(player, 0)

# Manage player health
func on_player_hit(p_num):
	if state != "playing":
		return
	player_data[p_num].hp -= 1
	if player_data[p_num].hp == 0:
		player_data[p_num].node.queue_free()
		Input.start_joy_vibration(player_data[p_num].pad, .2, .2, .3)
		if player_data.size() == 2:
			state = "ending"
			set_msg("Game ended!")
			ending_timer.start(3)
	var bits = player_data[p_num].hud.get_children()
	for i in range(health):
		bits[i].modulate.a = 1.0 if player_data[p_num].hp > i else 0.1

# Check if a pad is already used
func is_new_pad(id):
	for player in player_data:
		if player.pad == id:
			return false
	return true

# Set message text and visibility
func set_msg(msg):
	$UI/Msg/Panel/Message.text = msg
	$UI/Msg/.visible = msg != ""

# Increment/decrement values of options
func crement(item, x):
	if item == "hp":
		health = clamp(health + x, 1, 5)
		get_node(menu_local + "Health/HealthNum").text = str(health)
	if item == "balls":
		balls = clamp(balls + x, 1, 10)
		get_node(menu_local + "Balls/BallNum").text = str(balls)
