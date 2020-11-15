extends Node

onready var menu = get_node("MenuLayer/Menu")
onready var host_button = get_node("MenuLayer/Menu/Main/HostButton")
onready var address_input = get_node("MenuLayer/Menu/Main/Address")
onready var join_button = get_node("MenuLayer/Menu/Main/JoinButton")
onready var message = get_node("MenuLayer/Menu/Main/Message")
onready var game = get_node("Game")
onready var player_spawn = get_node("Game/TestMap/PlayerSpawns/PlayerSpawn").position
onready var camera = get_node("Game/Camera2D")
onready var players = get_node("Game/Players")

var player_data = {}
var playing = false
onready var self_data = {position = player_spawn, rotation = 0}

func _ready():
	get_tree().connect("network_peer_connected", self, "network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "network_peer_disconnected")
	get_tree().connect("connection_failed", self, "connection_failed")
	get_tree().connect("server_disconnected", self, "server_disconnected")
	randomize()
	self_data.color = Color.from_hsv(randf(), 1, 1)

func network_peer_connected(id):
	if not get_tree().is_network_server():
		rpc_id(1, "request_data", get_tree().get_network_unique_id(), id)

func network_peer_disconnected(id):
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
	player_data.erase(id)

func connected_to_server():
	load_game()
	player_data[get_tree().get_network_unique_id()] = self_data
	rpc("send_data", get_tree().get_network_unique_id(), self_data)

func connection_failed():
	reset("Connection failed")

func server_disconnected():
	reset("Server disconnected")

remote func request_data(from_id, peer_id):
	if get_tree().is_network_server():
		rpc_id(from_id, "send_data", peer_id, player_data[peer_id])

remote func send_data(id, data):
	player_data[id] = data
	init_player(id, data)

func _on_HostButton_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 4)
	get_tree().set_network_peer(peer)
	player_data[1] = self_data
	load_game()

func _on_JoinButton_pressed():
	message.text = "Connecting"
	if not address_input.get_text().is_valid_ip_address():
		return
	get_tree().connect("connected_to_server", self, "connected_to_server")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address_input.get_text(), 8910)
	get_tree().set_network_peer(peer)

func _on_BackButton_pressed():
	get_tree().change_scene("res://main/main.tscn")

func load_game():
	message.text = ""
	menu.hide()
	game.show()
	init_player(get_tree().get_network_unique_id(), self_data)
	playing = true

func reset(msg):
	playing = false
	message.text = msg
	for p in players.get_children():
		p.queue_free()
	player_data.empty()
	menu.show()
	game.hide()
	get_tree().set_deferred("network_peer", null)

func init_player(id, data):
	var new_player = load("res://online/player.tscn").instance()
	new_player.name = str(id)
	new_player.set_network_master(id)
	new_player.modulate = data.color
	new_player.connect("update", self, "update_player")
	players.add_child(new_player)
	new_player.position = data.position
	new_player.rotation = data.rotation

func update_player(id, position, rotation):
	player_data[id].position = position
	player_data[id].rotation = rotation

func _process(_delta):
	if playing and player_data.size() > 0:
		camera.position = players.get_node(str(get_tree().get_network_unique_id())).position
	if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
		reset("")
