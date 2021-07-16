extends Node

onready var camera = $Camera
onready var map_manager = $MapManager
onready var paddle_manager = $PaddleManager
onready var ball_manager = $BallManager
onready var ui = $CanvasLayer/UI

func _ready():
	DiscordManager.connect("UserUpdated", self, "get_user")
	DiscordManager.connect("LobbyCreated", self, "create_game")
	DiscordManager.connect("LobbyConnected", self, "request_check")
	DiscordManager.connect("LobbyDeleted", self, "unload_game", ["Server disconnected"])
	DiscordManager.connect("MemberDisconnected", self, "handle_member_disconnect")
	DiscordManager.connect("MessageReceived", self, "handle_discord_message")
	DiscordManager.connect("RelationshipsUpdated", ui, "update_friends")
	DiscordManager.connect("InviteReceived", ui, "show_invite")
	paddle_manager.connect("options_requested", self, "toggle_options")
	paddle_manager.connect("paddle_created", ui, "create_bar")
	paddle_manager.connect("paddle_damaged", ui, "update_bar")
	paddle_manager.connect("paddle_destroyed", ui, "set_message", [2])
	paddle_manager.connect("paddle_removed", ui, "remove_bar")
	ui.connect("map_switched", self, "switch_map")
	ui.connect("start_requested", DiscordManager, "CreateLobby")
	ui.connect("end_requested", self, "unload_game", ["You left the game"])

func _physics_process(_delta):
	if Game.is_playing:
		if Game.is_lobby_owner():
			var update_data = {
				"paddles": paddle_manager.paddles,
				"balls": ball_manager.balls,
			}
			DiscordManager.SendDataAll(Game.Channels.UPDATE_OBJECTS, update_data)
			update_objects(paddle_manager.paddles, ball_manager.balls)
		camera.move_and_zoom(paddle_manager.get_children())

func get_user():
	Game.user_id = DiscordManager.GetUserId()
	Game.username = DiscordManager.GetUsername()
	ui.name_label.text = Game.username

func request_check():
	var check_data = {
		"version": Game.VERSION,
		"id": DiscordManager.GetUserId(),
	}
	DiscordManager.SendDataOwner(Game.Channels.CHECK_MEMBER, check_data)

func toggle_options():
	ui.toggle_options()

func handle_discord_message(channel_id, data):
	var parsed_data = bytes2var(data)
	if channel_id == Game.Channels.UPDATE_OBJECTS:
		update_objects(parsed_data.paddles, parsed_data.balls)
	elif channel_id == Game.Channels.CHECK_MEMBER:
		check_member(parsed_data.id, parsed_data.version)
	elif channel_id == Game.Channels.JOIN_GAME:
		join_game(parsed_data.paddles, parsed_data.map, parsed_data.color)
	elif channel_id == Game.Channels.UNLOAD_GAME:
		unload_game(parsed_data.reason)
	elif channel_id == Game.Channels.CREATE_PADDLE:
		paddle_manager.create_paddle(parsed_data)
	elif channel_id == Game.Channels.SET_PADDLE_INPUTS:
		paddle_manager.set_paddle_inputs(parsed_data.paddle, parsed_data.inputs)
	elif channel_id == Game.Channels.VIBRATE_PAD:
		paddle_manager.vibrate_pad(parsed_data.paddle)
	elif channel_id == Game.Channels.DAMAGE_PADDLE:
		paddle_manager.damage_paddle(parsed_data.paddle)

func switch_map():
	ui.map_button.text = map_manager.switch()

func handle_member_disconnect(id):
	paddle_manager.remove_paddles(id)
	ui.bar_parent.columns = max(paddle_manager.paddles.size(), 1)
	ui.set_message("Client disconnected", 2)

func check_member(id, version):
	if version == Game.VERSION:
		ui.set_message("Client connected", 2)
		var game_data = {
			"paddles": paddle_manager.paddles,
			"map": Game.map,
			"color": map_manager.color,
		}
		DiscordManager.SendData(id, Game.Channels.JOIN_GAME, game_data)
	else:
		var unload_data = {
			"reason": "Different server version (" + Game.VERSION + ")",
		}
		DiscordManager.SendData(id, Game.Channels.UNLOAD_GAME, unload_data)

func join_game(paddles, map_name, map_color):
	load_game(map_name, map_color)
	for paddle in paddles:
		paddle_manager.create_paddle(paddles[paddle])

func create_game():
	randomize()
	load_game(Game.map, Color.from_hsv(randf(), 0.8, 1))

func load_game(map_name, map_color):
	map_manager.load_map(map_name, map_color)
	camera.reset(map_manager.get_camera_spawn())
	paddle_manager.spawns = map_manager.get_paddle_spawns()
	ball_manager.spawns = map_manager.get_ball_spawns()
	ball_manager.create_balls()
	ui.set_message("Press A/Enter to create your paddle", 5)
	ui.main_menu_node.hide()
	Game.is_playing = true

func update_objects(paddles, balls):
	if Game.is_playing:
		paddle_manager.update_paddles(paddles)
		ball_manager.update_balls(balls)

func unload_game(msg):
	Game.reset()
	camera.reset()
	map_manager.reset()
	paddle_manager.reset()
	ball_manager.reset()
	ui.reset(msg)
