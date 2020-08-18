extends Node2D

onready var main_menu = "UILayer/Menu/Panel/Main/"
onready var message = get_node("UILayer/Msg/Panel/Message")
onready var defCamPos = get_node("Game/TestMap/DefCamPos").position
onready var camera = get_node("Game/Camera2D")
onready var players = get_node("Game/Players")
onready var bars = get_node("UILayer/HUD/Bars")
onready var player_spawns = get_node("Game/TestMap/PlayerSpawns")

var state = {"idle": 0, "starting": 1, "playing": 2, "ending": 3}
var current_state = state.idle
var max_players = 8
var max_hp = 3
var max_balls = 10
var player_db = []
var used_colors = []
var zoom_margin = 500
var zoom_accel = 0.05

func _ready():
	get_node(main_menu + "Color").connect("pressed", self, "new_color")
	get_node(main_menu + "CRT").connect("pressed", self, "toggle_crt")
	get_node(main_menu + "Play").connect("pressed", self, "load_game")
	get_node(main_menu + "Quit").connect("pressed", get_tree(), "quit")
	get_node(main_menu + "Health/Dec").connect("pressed", self, "crement", ["hp", -1])
	get_node(main_menu + "Health/Inc").connect("pressed", self, "crement", ["hp", 1])
	get_node(main_menu + "Balls/Dec").connect("pressed", self, "crement", ["balls", -1])
	get_node(main_menu + "Balls/Inc").connect("pressed", self, "crement", ["balls", 1])
	get_node("ResetTimer").connect("timeout", self, "unload_game")
	get_node(main_menu + "Play").grab_focus()
	update_option_nodes()
	new_color()
	update_balls()
	camera.position = defCamPos

# New random map color
func new_color():
	var prev_color = get_node("Game/TestMap").modulate
	used_colors = []
	var map_color = prev_color
	while map_color == prev_color:
		randomize()
		map_color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	used_colors.append(map_color)
	get_node("Game/TestMap").modulate = map_color

# Toggle CRT filter shader
func toggle_crt():
	get_node("UILayer/Shader").visible = !get_node("UILayer/Shader").visible

# Update UI when changing settings
func update_option_nodes():
	get_node(main_menu + "Health/HealthNum").text = str(max_hp)
	get_node(main_menu + "Balls/BallNum").text = str(max_balls)

# Set message text and visibility
func set_msg(msg, show):
	message.text = msg
	message.get_parent().get_parent().visible = show

# Increment/decrement values of options
func crement(item, x):
	if item == "hp":
		max_hp = clamp(max_hp + x, 1, 5)
	if item == "balls":
		max_balls = clamp(max_balls + x, 1, 10)
		update_balls()
	update_option_nodes()

# Reset all the balls
func update_balls():
	for ball in get_node("Game/Balls").get_children():
		ball.queue_free()
	for i in max_balls:
		var ball = load("res://Ball.tscn").instance()
		ball.position = get_node("Game/TestMap/BallSpawns").get_child(i).position
		get_node("Game/Balls").add_child(ball)

# Set up game, wait for players
func load_game():
	current_state = state.starting
	set_msg("Waiting for players to join...\nPress Enter/Start to join (or begin)", true)
	get_node("UILayer/Menu").hide()
	get_node("Game").modulate = Color(1, 1, 1)
	camera.position = defCamPos

# Signal player nodes to begin
func start_game():
	set_msg("", false)
	for p in player_db:
		p.node.game_began()
	current_state = state.playing

# Reset and clear players/balls
func unload_game():
	current_state = state.idle
	get_node("ResetTimer").stop()
	camera.position = defCamPos
	camera.zoom = Vector2(2, 2)
	set_msg("", false)
	player_db.clear()
	for p in players.get_children():
		p.queue_free()
	update_balls()
	for b in bars.get_children():
		b.queue_free()
	bars.columns = 1
	get_node("UILayer/Menu").show()
	get_node("Game").modulate = Color(1, 1, 1, 0.5)
	get_node(main_menu + "Play").grab_focus()

# Create new player
func new_player(id):
	# Create player node and color
	var p_num = player_db.size()
	var new_player = load("res://Player.tscn").instance()
	new_player.name = str(p_num)
	new_player.pad = id
	var new_color = used_colors[0]
	while used_colors.has(new_color):
		randomize()
		new_color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	used_colors.append(new_color)
	new_player.modulate = new_color
	
	# Add new HP bar for player
	var new_bar = HBoxContainer.new()
	new_bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	new_bar.modulate = new_color
	new_bar.alignment = BoxContainer.ALIGN_CENTER
	var hp_bar = HBoxContainer.new()
	hp_bar.set("custom_constants/separation", -18)
	for _x in range(max_hp):
		var hp_bit = TextureRect.new()
		hp_bit.texture = load("res://img/hp.png")
		hp_bar.add_child(hp_bit)
	new_bar.add_child(hp_bar)
	bars.add_child(new_bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	# Add player node and data
	new_player.spawn_pos = player_spawns.get_child(p_num).position
	new_player.spawn_rot = player_spawns.get_child(p_num).rotation
	new_player.connect("hit", self, "on_player_hit")
	player_db.append({pad = id, hp = max_hp, color = new_color, hud = hp_bar, node = new_player})
	players.add_child(new_player)
	players.move_child(new_player, 0)

# Manage player health
func on_player_hit(p_num):
	if current_state != state.playing:
		return
	player_db[p_num].node.damage()
	player_db[p_num].hp -= 1
	if player_db[p_num].hp == 0:
		player_db[p_num].node.queue_free()
		if player_db[p_num].pad >= 0:
			Input.start_joy_vibration(player_db[p_num].pad, .2, .2, .3)
		if players.get_child_count() == 2:
			current_state = state.ending
			set_msg("Game ended!", true)
			get_node("ResetTimer").start(3)
	var hp_bits = player_db[p_num].hud.get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(.3, .3, .3, .3)
		if player_db[p_num].hp > i:
			hp_bits[i].modulate = Color(1, 1, 1, 1)

# Check if a pad is already used
func is_new_pad(id):
	for p in player_db:
		if p.pad == id:
			return false
	return true

func _process(_delta):
	# Create player if sensed input
	if player_db.size() < max_players and current_state == state.starting:
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, JOY_START) and is_new_pad(c):
					new_player(c)
	
	# Start game when player one presses start/enter
	if current_state == state.starting and player_db.size() > 1:
		if player_db[0].pad == -1 and Input.is_key_pressed(KEY_ENTER):
			start_game()
		if player_db[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER):
			start_game()
		if player_db[0].pad >= 0 and Input.is_joy_button_pressed(player_db[0].pad, JOY_START):
			start_game()
	
	# Center camera to average player position, zoom camera to always view all players
	if current_state != state.idle and players.get_child_count() > 0:
		var avg = Vector2.ZERO
		for player in players.get_children():
			avg.x += player.position.x
			avg.y += player.position.y
		camera.position = avg / players.get_child_count()
		
		var max_x = players.get_child(0).position.x
		var min_x = players.get_child(0).position.x
		var max_y = players.get_child(0).position.y
		var min_y = players.get_child(0).position.y
		for player in players.get_children():
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		var new_zoom = Vector2.ZERO
		var new_zoom_x = (abs(max_x - min_x) + zoom_margin) / OS.window_size.x
		var new_zoom_y = (abs(max_y - min_y) + zoom_margin) / OS.window_size.y
		new_zoom = Vector2(max(new_zoom_x, new_zoom_y), max(new_zoom_x, new_zoom_y))
		new_zoom = Vector2(1, 1) if new_zoom < Vector2(1, 1) else new_zoom
		camera.zoom = camera.zoom.linear_interpolate(new_zoom, zoom_accel)
