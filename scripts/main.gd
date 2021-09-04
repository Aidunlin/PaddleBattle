extends Node

onready var camera = $Camera
onready var map_manager = $MapManager
onready var paddle_manager = $PaddleManager
onready var ball_manager = $BallManager
onready var hud_manager = $HUDManager
onready var ui_manager = $CanvasLayer/UIManager

func _ready():
	DiscordManager.connect("Error", ui_manager, "add_message")
	DiscordManager.connect("UserUpdated", self, "get_user")
	DiscordManager.connect("LobbyCreated", self, "create_game")
	DiscordManager.connect("MemberConnected", self, "handle_connect")
	DiscordManager.connect("MemberDisconnected", self, "handle_disconnect")
	DiscordManager.connect("MessageReceived", self, "handle_message")
	DiscordManager.connect("InviteReceived", ui_manager, "show_invite")
	paddle_manager.connect("options_requested", ui_manager, "show_options")
	paddle_manager.connect("paddle_destroyed", ui_manager, "add_message")
	paddle_manager.connect("paddle_created", hud_manager, "create_hud")
	paddle_manager.connect("paddle_damaged", hud_manager, "update_hud")
	paddle_manager.connect("paddle_removed", hud_manager, "remove_hud")
	ui_manager.connect("map_switched", self, "switch_map")
	ui_manager.connect("end_requested", self, "unload_game", ["You left the lobby"])

func _physics_process(_delta):
	if Game.is_playing:
		if DiscordManager.IsLobbyOwner():
			var object_data = {
				"paddles": paddle_manager.paddles,
				"balls": ball_manager.balls,
			}
			DiscordManager.SendAll(object_data, false)
			update_objects(paddle_manager.paddles, ball_manager.balls)
		camera.move_and_zoom(paddle_manager.get_children())

func switch_map():
	ui_manager.map_button.text = map_manager.switch()

func get_user():
	if not Game.is_playing and not ui_manager.main_menu_node.visible:
		Game.user_id = DiscordManager.GetUserId()
		Game.user_name = DiscordManager.GetUserName()
		ui_manager.show_user_and_menu()

func handle_message(message):
	var data = bytes2var(message)
	if "paddles" in data and "balls" in data:
		update_objects(data.paddles, data.balls)
	elif "paddle" in data and "inputs" in data:
		paddle_manager.set_paddle_inputs(data.paddle, data.inputs)
	elif "paddles" in data and "map" in data:
		join_game(data.paddles, data.map)
	elif "reason" in data:
		unload_game(data.reason)
	elif "paddle" in data:
		paddle_manager.damage_paddle(data.paddle)
	elif "name" in data:
		paddle_manager.create_paddle(data)

func handle_connect(id, name):
	ui_manager.add_message(name + " joined the lobby")
	if DiscordManager.IsLobbyOwner():
		var welcome_data = {
			"paddles": paddle_manager.paddles,
			"map": Game.map,
		}
		DiscordManager.Send(id, welcome_data, true)

func handle_disconnect(id, name):
	paddle_manager.remove_paddles(id)
	ui_manager.add_message(name + " left the lobby")

func join_game(paddles, map_name):
	create_game(map_name)
	for paddle in paddles:
		paddle_manager.create_paddle(paddles[paddle])

func create_game(map_name = Game.map):
	randomize()
	load_game(map_name, Color.from_hsv(randf(), 0.8, 1))

func load_game(map_name, map_color):
	map_manager.load_map(map_name, map_color)
	camera.reset(map_manager.get_camera_spawn())
	paddle_manager.spawns = map_manager.get_paddle_spawns()
	ball_manager.spawns = map_manager.get_ball_spawns()
	ball_manager.create_balls()
	ui_manager.add_message("Press A/Enter to join")
	ui_manager.main_menu_node.hide()
	Game.is_playing = true

func update_objects(paddles, balls):
	if Game.is_playing:
		paddle_manager.update_paddles(paddles)
		hud_manager.move_huds(paddles)
		ball_manager.update_balls(balls)

func unload_game(msg):
	DiscordManager.LeaveLobby()
	Game.is_playing = false
	camera.reset()
	map_manager.reset()
	paddle_manager.reset()
	ball_manager.reset()
	hud_manager.reset()
	ui_manager.reset(msg)
