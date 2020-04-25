extends Node

onready var menu = get_node("Menu")
onready var host_button = get_node("Menu/Main/HostButton")
onready var address_input = get_node("Menu/Main/Address")
onready var join_button = get_node("Menu/Main/JoinButton")
onready var game = get_node("Game")
onready var player_spawn = get_node("Game/TestMap/SpawnPosition").position
onready var camera = get_node("Game/Camera2D")
onready var players = get_node("Game/Players")

var player_data = {}
onready var self_data = {position = player_spawn, rotation = 0}

func _ready():
	get_tree().connect("network_peer_connected", self, "network_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "network_peer_disconnected")
	get_tree().connect("connection_failed", self, "connection_failed")
	get_tree().connect("server_disconnected", self, "server_disconnected")

func network_peer_connected(id):
	if not get_tree().is_network_server():
		rpc_id(1, "request_data", get_tree().get_network_unique_id(), id)

func network_peer_disconnected(id):
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
	player_data.erase(id)

func connected_to_server():
	player_data[get_tree().get_network_unique_id()] = self_data
	rpc("send_data", get_tree().get_network_unique_id(), self_data)

func connection_failed():
	get_tree().reload_current_scene()

func server_disconnected():
	get_tree().reload_current_scene()

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
	if not address_input.get_text().is_valid_ip_address():
		return
	get_tree().connect("connected_to_server", self, "connected_to_server")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address_input.get_text(), 8910)
	get_tree().set_network_peer(peer)
	load_game()

func load_game():
	menu.hide()
	game.show()
	camera.current = true
	init_player(get_tree().get_network_unique_id(), self_data)

func init_player(id, data):
	var new_player = load("res://Player.tscn").instance()
	new_player.name = str(id)
	new_player.set_network_master(id)
	new_player.connect("update", self, "update_player")
	players.add_child(new_player)
	new_player.position = data.position
	new_player.rotation = data.rotation

func update_player(id, position, rotation):
	player_data[id].position = position
	player_data[id].rotation = rotation

func _process(_delta):
	if player_data.size() > 0:
		camera.position = players.get_node(str(get_tree().get_network_unique_id())).position
