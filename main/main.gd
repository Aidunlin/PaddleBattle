extends Node

const MAP_SCENE = preload("res://map/map.tscn")
const SMALL_MAP_SCENE = preload("res://map/smallmap.tscn")

onready var camera = $Camera
onready var map_parent = $Map
onready var paddle_manager = $PaddleManager
onready var ball_manager = $BallManager
onready var ui = $CanvasLayer/UI
onready var join_timer = $JoinTimer

func _ready():
	get_tree().connect("network_peer_disconnected", self, "handle_peer_disconnect")
	get_tree().connect("connected_to_server", self,"rpc_id", [1, "check_client", Game.VERSION])
	get_tree().connect("connection_failed", self, "unload_game", ["Connection failed"])
	get_tree().connect("server_disconnected", self, "unload_game", ["Server disconnected"])
	paddle_manager.connect("unload_requested", self, "unload_game", ["You left the game"])
	paddle_manager.connect("paddle_created", ui, "create_bar")
	paddle_manager.connect("paddle_damaged", ui, "update_bar")
	paddle_manager.connect("paddle_destroyed", ui, "set_message", [2])
	paddle_manager.connect("paddle_removed", ui, "remove_bar")
	ui.connect("start_requested", self, "start_server_game")
	ui.connect("connect_requested", self, "connect_to_server")
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])

func _physics_process(_delta):
	if Game.is_playing:
		if Network.peer_id == 1:
			rpc_unreliable("update_objects", paddle_manager.paddles, ball_manager.balls)
			Network.broadcast_server()
		camera.move_and_zoom(paddle_manager.get_children())

func connect_to_server(ip):
	Game.config.peer_name = ui.name_input.text
	Game.config.ip = ip
	if ip.is_valid_ip_address():
		ui.set_message("Trying to connect...")
		paddle_manager.initial_max_health = Game.config.max_health
		Network.setup_client(ip)
		join_timer.start(3)
		ui.toggle_inputs(true)
	else:
		ui.set_message("Invalid IP", 3)
		ui.ip_input.grab_focus()
	Game.save_config()

func handle_peer_disconnect(id):
	paddle_manager.remove_paddles(id)
	ui.bar_parent.columns = max(paddle_manager.paddles.size(), 1)
	ui.set_message("Client disconnected", 2)

remote func check_client(version):
	var id = get_tree().get_rpc_sender_id()
	if version == Game.VERSION:
		ui.set_message("Client connected", 2)
		rpc_id(id, "start_client_game", paddle_manager.paddles, Game.config.using_small_map,
				map_parent.modulate, Game.config.max_health, Game.config.ball_count)
	else:
		rpc_id(id, "unload_game", "Different server version (" + Game.VERSION + ")")

remote func start_client_game(paddles, small_map, map_color, health, balls):
	ui.toggle_inputs(false)
	join_timer.stop()
	load_game(small_map, map_color, balls)
	Game.config.max_health = health
	for paddle in paddles:
		paddle_manager.create_paddle(paddles[paddle])

func start_server_game():
	Game.config.peer_name = ui.name_input.text
	Network.setup_server()
	var map_color = Color.from_hsv(randf(), 0.8, 1)
	load_game(Game.config.using_small_map, map_color, Game.config.ball_count)

func load_game(small_map, map_color, ball_count):
	Game.save_config()
	map_parent.modulate = map_color
	if small_map:
		map_parent.add_child(SMALL_MAP_SCENE.instance())
	else:
		map_parent.add_child(MAP_SCENE.instance())
	camera.reset(map_parent.get_child(0).get_node("CameraSpawn").position)
	paddle_manager.spawns = map_parent.get_child(0).get_node("PaddleSpawns").get_children()
	ball_manager.spawns = map_parent.get_child(0).get_node("BallSpawns").get_children()
	ball_manager.create_balls(ball_count)
	ui.set_message("Press A/Enter to create your paddle", 5)
	ui.menu_node.hide()
	Game.is_playing = true

remote func unload_game(msg):
	Game.is_playing = false
	if get_tree().has_network_peer():
		if Network.peer_id != 1:
			Game.config.max_health = paddle_manager.initial_max_health
		Network.reset()
	join_timer.stop()
	camera.reset()
	if map_parent.get_child_count() > 0:
		map_parent.get_child(0).queue_free()
	paddle_manager.reset()
	ball_manager.reset()
	ui.reset(msg)

remotesync func update_objects(paddles, balls):
	if Game.is_playing:
		paddle_manager.update_paddles(paddles)
		ball_manager.update_balls(balls)
