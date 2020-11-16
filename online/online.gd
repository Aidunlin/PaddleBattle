extends Node

onready var address = $UI/Menu/Panel/Main/JoinBar/Address
onready var message = $UI/Menu/Panel/Main/Message
onready var camera = $Game/Camera
onready var players = $Game/Players

var menu = "UI/Menu/Panel/Main/"
var player_data = {}
var playing = false
onready var self_data = {position = $Game/TestMap/CameraSpawn.position, rotation = 0}

func _ready():
	get_node(menu + "Host").grab_focus()
	get_node(menu + "Host").connect("pressed", self, "host_pressed")
	get_node(menu + "JoinBar/Join").connect("pressed", self, "join_pressed")
	get_node(menu + "Back").connect("pressed", self, "back_pressed")
	get_tree().connect("network_peer_connected", self, "peer_connected")
	get_tree().connect("network_peer_disconnected", self, "peer_disconnected")
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])
	randomize()
	self_data.color = Color.from_hsv(randf(), 1, 1)

func _process(_delta):
	if playing:
		camera.position = self_data.position

func _input(_event):
	if playing:
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game("")

func host_pressed():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910, 4)
	get_tree().set_network_peer(peer)
	player_data[1] = self_data
	load_game()

func join_pressed():
	message.text = "Connecting"
	var address_text = address.text
	if not address_text.is_valid_ip_address():
		if address_text != "":
			return
		address_text = "127.0.0.1"
	get_tree().connect("connected_to_server", self, "connected_to_server")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address_text, 8910)
	get_tree().set_network_peer(peer)

func back_pressed():
	get_tree().change_scene("res://main/main.tscn")

func peer_connected(id):
	if not get_tree().is_network_server():
		rpc_id(1, "request_data", get_tree().get_network_unique_id(), id)

func peer_disconnected(id):
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
	player_data.erase(id)

func connected_to_server():
	load_game()
	player_data[get_tree().get_network_unique_id()] = self_data
	rpc("send_data", get_tree().get_network_unique_id(), self_data)

remote func request_data(from_id, peer_id):
	if get_tree().is_network_server():
		rpc_id(from_id, "send_data", peer_id, player_data[peer_id])

remote func send_data(id, data):
	player_data[id] = data
	init_player(id, data)

func load_game():
	message.text = ""
	$UI/Menu.hide()
	$Game.show()
	init_player(get_tree().get_network_unique_id(), self_data)
	playing = true

func unload_game(msg):
	playing = false
	message.text = msg
	for p in players.get_children():
		p.queue_free()
	player_data.empty()
	$UI/Menu.show()
	$Game.hide()
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
