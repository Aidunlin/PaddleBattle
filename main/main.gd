extends Node

onready var camera = $Camera
onready var map_manager = $MapManager
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
	ui.connect("map_switched", self, "switch_map")
	ui.connect("start_requested", self, "start_server_game")
	ui.connect("connect_requested", self, "connect_to_server")
	join_timer.connect("timeout", self, "unload_game", ["Connection failed"])

func _physics_process(_delta):
	if Game.is_playing:
		if Network.peer_id == 1:
			rpc_unreliable("update_objects", paddle_manager.paddles, ball_manager.balls)
		camera.move_and_zoom(paddle_manager.get_children())

func switch_map():
	var new_map_name = map_manager.switch()
	ui.map_button.text = new_map_name

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
		rpc_id(id, "start_client_game", paddle_manager.paddles, Game.config.map, map_manager.color, Game.config.max_health, Game.config.ball_count)
	else:
		rpc_id(id, "unload_game", "Different server version (" + Game.VERSION + ")")

remote func start_client_game(paddles, map_name, map_color, health, balls):
	ui.toggle_inputs(false)
	join_timer.stop()
	load_game(map_name, map_color, balls)
	Game.config.max_health = health
	for paddle in paddles:
		paddle_manager.create_paddle(paddles[paddle])

func start_server_game():
	Game.config.peer_name = ui.name_input.text
	Network.setup_server()
	randomize()
	var map_color = Color.from_hsv(randf(), 0.8, 1)
	load_game(Game.config.map, map_color, Game.config.ball_count)

func load_game(map_name, map_color, ball_count):
	Game.save_config()
	map_manager.load_map(map_name, map_color)
	camera.reset(map_manager.get_camera_spawn())
	paddle_manager.spawns = map_manager.get_paddle_spawns()
	ball_manager.spawns = map_manager.get_ball_spawns()
	ball_manager.create_balls(ball_count)
	ui.set_message("Press A/Enter to create your paddle", 5)
	ui.menu_node.hide()
	Game.is_playing = true

remotesync func update_objects(paddles, balls):
	if Game.is_playing:
		paddle_manager.update_paddles(paddles)
		ball_manager.update_balls(balls)

remote func unload_game(msg):
	Game.is_playing = false
	if get_tree().has_network_peer():
		if Network.peer_id != 1:
			Game.config.max_health = paddle_manager.initial_max_health
		Network.reset()
	join_timer.stop()
	camera.reset()
	map_manager.reset()
	paddle_manager.reset()
	ball_manager.reset()
	ui.reset(msg)
	ui.refresh_servers()
