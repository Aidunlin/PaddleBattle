extends Node

onready var camera = $Camera
onready var map_manager = $MapManager
onready var paddle_manager = $PaddleManager
onready var ball_manager = $BallManager
onready var hud_manager = $HUDManager
onready var ui_manager = $CanvasLayer/UIManager

func _ready():
	DiscordManager.connect("user_updated", self, "get_user")
	DiscordManager.connect("lobby_created", self, "create_game")
	DiscordManager.connect("lobby_connected", self, "request_check")
	DiscordManager.connect("member_connected", self, "handle_member_connect")
	DiscordManager.connect("member_disconnected", self, "handle_member_disconnect")
	DiscordManager.connect("message_received", self, "handle_discord_message")
	DiscordManager.connect("invite_received", ui_manager, "show_invite")
	paddle_manager.connect("options_requested", ui_manager, "show_options")
	paddle_manager.connect("paddle_destroyed", ui_manager, "add_message")
	paddle_manager.connect("paddle_created", hud_manager, "create_hud")
	paddle_manager.connect("paddle_damaged", hud_manager, "update_hud")
	paddle_manager.connect("paddle_removed", hud_manager, "remove_hud")
	ui_manager.connect("map_switched", self, "switch_map")
	ui_manager.connect("end_requested", self, "unload_game", ["You left the lobby"])

func _physics_process(_delta):
	if Game.is_playing:
		if DiscordManager.is_lobby_owner():
			var update_data = {
				"paddles": paddle_manager.paddles,
				"balls": ball_manager.balls,
			}
			DiscordManager.send_data_all(Game.channels.UPDATE_OBJECTS, update_data)
			update_objects(paddle_manager.paddles, ball_manager.balls)
		camera.move_and_zoom(paddle_manager.get_children())

func switch_map():
	ui_manager.map_button.text = map_manager.switch()

func get_user():
	if not Game.is_playing and not ui_manager.main_menu_node.visible:
		Game.user_id = DiscordManager.get_user_id()
		Game.user_name = DiscordManager.get_user_name()
		ui_manager.name_label.text = Game.user_name
		ui_manager.main_menu_node.show()
		ui_manager.play_button.grab_focus()

func handle_discord_message(channel_id, data):
	var parsed_data = bytes2var(data)
	match channel_id:
		Game.channels.UPDATE_OBJECTS:
			update_objects(parsed_data.paddles, parsed_data.balls)
		Game.channels.SET_PADDLE_INPUTS:
			paddle_manager.set_paddle_inputs(parsed_data.paddle, parsed_data.inputs)
		Game.channels.JOIN_GAME:
			join_game(parsed_data.paddles, parsed_data.map)
		Game.channels.UNLOAD_GAME:
			unload_game(parsed_data.reason)
		Game.channels.CREATE_PADDLE:
			paddle_manager.create_paddle(parsed_data)
		Game.channels.DAMAGE_PADDLE:
			paddle_manager.damage_paddle(parsed_data.paddle)

func handle_member_connect(id, name):
	ui_manager.add_message(name + " joined the lobby")
	if DiscordManager.is_lobby_owner():
		var game_data = {
			"paddles": paddle_manager.paddles,
			"map": Game.map,
		}
		DiscordManager.send_data(id, Game.channels.JOIN_GAME, game_data)

func handle_member_disconnect(id, name):
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
	Game.reset()
	camera.reset()
	map_manager.reset()
	paddle_manager.reset()
	ball_manager.reset()
	hud_manager.reset()
	ui_manager.reset(msg)
