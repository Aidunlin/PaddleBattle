extends Node

const PORT = 8910
onready var name_text = get_node("Menu/Main/Name")
onready var host_button = get_node("Menu/Main/HostButton")
onready var address_text = get_node("Menu/Main/Address")
onready var join_button = get_node("Menu/Main/JoinButton")
onready var message = get_node("Menu/Main/Message")
onready var lobby = get_node("Menu/Lobby")
onready var start_button = get_node("Menu/Lobby/StartButton")
onready var player_list = get_node("Menu/Lobby/Players")

var players = {}

func _ready():
	get_tree().connect("network_peer_connected", self, "_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self,"_network_peer_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_to_server")
	get_tree().connect("connection_failed", self, "_connection_failed")
	get_tree().connect("server_disconnected", self, "_server_disconnected")



### SceneTree callbacks

func _network_peer_connected(id): # Server/Client
	rpc_id(id, "new_player", name_text.get_text())

func _network_peer_disconnected(id): # Server/Client
	if has_node("Game"):
		if get_tree().is_network_server():
			message.set_text(players[id] + " disconnected")
			end_game()
	else:
		remove_player(id)

func _connected_to_server(): # Client
	message.set_text("")
	host_button.set_disabled(false)
	join_button.set_disabled(false)
	lobby.show()

func _connection_failed(): # Client
	get_tree().set_network_peer(null)
	message.set_text("Connection failed")
	host_button.set_disabled(false)
	host_button.set_disabled(false)
	lobby.hide()

func _server_disconnected(): # Client
	message.set_text("Server disconnected")
	end_game()

### Lobby management

remote func new_player(name):
	var id = get_tree().get_rpc_sender_id()
	print(id)
	players[id] = name
	update_player_list()

func remove_player(id):
	players.erase(id)
	update_player_list()

func update_player_list():
	players.values().sort()
	player_list.clear()
	player_list.add_item(name_text.get_text() + " (you)")
	for p in players.values():
		if get_tree().is_network_server():
			player_list.add_item(p)
		else:
			if p == players[1]:
				player_list.add_item(p + " (host)")
			else:
				player_list.add_item(p)
	if not get_tree().is_network_server():
		start_button.hide()

func end_game():
	if has_node("Game"):
		get_node("Game").queue_free()
	players.clear()
	$Menu.show()
	lobby.hide()
	host_button.set_disabled(false)
	join_button.set_disabled(false)
	get_tree().set_network_peer(null)

### Button press management

func _on_HostButton_pressed():
	if name_text.get_text() == "":
		message.set_text("Invalid name")
		return
	message.set_text("")
	var host = NetworkedMultiplayerENet.new()
	host.create_server(PORT, 7)
	get_tree().set_network_peer(host)
	start_button.show()
	lobby.show()
	update_player_list()

func _on_JoinButton_pressed():
	if name_text.get_text() == "":
		message.set_text("Invalid name")
		return
	var address = address_text.get_text()
	if not address.is_valid_ip_address():
		message.set_text("Invalid address")
		return
	message.set_text("Connecting")
	host_button.set_disabled(true)
	join_button.set_disabled(true)
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(address, PORT)
	get_tree().set_network_peer(peer)

func _on_StartButton_pressed():
	assert(get_tree().is_network_server())
	pass

func _on_QuitButton_pressed():
	get_tree().set_network_peer(null)
	host_button.set_disabled(false)
	join_button.set_disabled(false)
	start_button.hide()
	lobby.hide()

func _on_ExitButton_pressed():
	get_tree().quit()
