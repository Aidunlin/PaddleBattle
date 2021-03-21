extends Node

const SERVER_PORT = 8910
const SOCKET_PORT = 8191

var peer_id = 1
var broadcast_socket = PacketPeerUDP.new()
var listen_socket = PacketPeerUDP.new()
var server_list = {}

func _ready():
	listen_socket.listen(SOCKET_PORT)

func get_servers():
	server_list.clear()
	while listen_socket.get_available_packet_count() > 0:
		var ip = listen_socket.get_packet_ip()
		var port = listen_socket.get_packet_port()
		var data = listen_socket.get_packet()
		if ip != "" and port > 0 and not server_list.has(ip):
			var server_name = data.get_string_from_ascii()
			server_list[ip] = server_name
	return server_list

func setup_server():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(8910)
	get_tree().network_peer = peer
	get_tree().refuse_new_network_connections = not Game.config.is_open_to_lan
	if Game.config.is_open_to_lan:
		broadcast_socket.set_broadcast_enabled(true)
		broadcast_socket.set_dest_address("255.255.255.255", SOCKET_PORT)

func broadcast_server():
	if Game.config.is_open_to_lan:
		broadcast_socket.put_packet(Game.config.peer_name.to_ascii())

func setup_client(ip):
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, SERVER_PORT)
	get_tree().network_peer = peer
	peer_id = get_tree().get_network_unique_id()

func reset():
	get_tree().set_deferred("network_peer", null)
	peer_id = 1
