extends Node

onready var address = $UI/Menu/Panel/Main/JoinBar/Address
onready var message = $UI/Menu/Panel/Main/Message
onready var camera = $Game/Camera
onready var players = $Game/Players

var menu = "UI/Menu/Panel/Main/"
var player_data = {}
var ball_data = []
var balls = 10
var playing = false
onready var self_data = {position=$Game/TestMap/CameraSpawn.position, rotation=0}

func _ready():
	get_node(menu + "Host").grab_focus()
	get_node(menu + "Host").connect("pressed", self, "host_pressed")
	get_node(menu + "JoinBar/Join").connect("pressed", self, "join_pressed")
	get_node(menu + "Back").connect("pressed", self, "back_pressed")
	get_tree().connect("network_peer_connected", self, "peer_connected")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed!"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected!"])
	randomize()
	self_data.color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	$Game/TestMap.modulate = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)

func _process(_delta):
	if playing:
		camera.position = self_data.position
		if get_tree().is_network_server():
			rpc_unreliable("update_balls", ball_data)

func _input(_event):
	if playing:
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("")

# Button presses

func host_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 4)
	get_tree().set_network_peer(peer)
	player_data[1] = self_data
	load_game()

func join_pressed():
	var address_text = address.text
	if not address_text.is_valid_ip_address():
		if address_text != "":
			message.text = "Invalid IP!"
			return
		address_text = "127.0.0.1"
	message.text = "Connecting..."
	get_node(menu + "Host").disabled = true
	get_node(menu + "JoinBar/Join").disabled = true
	get_tree().connect("connected_to_server", self, "connected_to_server")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address_text, 8910)
	get_tree().set_network_peer(peer)

func back_pressed():
	get_tree().change_scene("res://main/main.tscn")

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

# Loading/unloading from game state

func load_game():
	message.text = ""
	get_node(menu + "Host").disabled = false
	get_node(menu + "JoinBar/Join").disabled = false
	$UI/Menu.hide()
	$Game.show()
	init_player(get_tree().get_network_unique_id(), self_data)
	playing = true
	init_balls()

func unload_game(msg):
	playing = false
	message.text = msg
	for p in $Game/Players.get_children():
		p.queue_free()
	player_data.clear()
	for ball in $Game/Balls.get_children():
		ball.queue_free()
	ball_data.clear()
	$UI/Menu.show()
	$Game.hide()
	get_tree().set_deferred("network_peer", null)

# Player funcs

func init_player(id, data):
	var player = load("res://online/player.tscn").instance()
	player.name = str(id)
	player.set_network_master(id)
	player.modulate = data.color
	player.connect("update", self, "update_player")
	$Game/Players.add_child(player)
	player.position = data.position
	player.rotation = data.rotation

func update_player(id, position, rotation):
	player_data[id].position = position
	player_data[id].rotation = rotation

# Ball funcs

func init_balls():
	for i in balls:
		if get_tree().is_network_server():
			var ball = load("res://ball/ball.tscn").instance()
			ball.position = $Game/TestMap/BallSpawns.get_child(i).position
			ball_data.append({position = ball.position, rotation = ball.rotation})
			$Game/Balls.add_child(ball)
		else:
			var ball = load("res://online/ball.tscn").instance()
			$Game/Balls.add_child(ball)

remotesync func update_balls(data):
	for i in balls:
		if get_tree().is_network_server():
			ball_data[i].position = $Game/Balls.get_child(i).position
			ball_data[i].rotation = $Game/Balls.get_child(i).rotation
		else:
			$Game/Balls.get_child(i).position = data[i].position
			$Game/Balls.get_child(i).rotation = data[i].rotation
