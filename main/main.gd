extends Node

onready var defCamPos = get_node("Game/TestMap/DefCamPos").position
onready var spawns = get_node("Game/TestMap/PlayerSpawns")
onready var bars = get_node("UILayer/HUD/Bars")
onready var message = get_node("UILayer/Msg/Panel/Message")

var menu_path = "UILayer/Menu/Panel/Main/"
var state = "idle"
var max_hp = 3
var max_balls = 10
var players = []
var used_colors = []
var reset_timer = Timer.new()

func _ready():
	get_node(menu_path + "Play").connect("pressed", self, "load_game")
	get_node(menu_path + "Quit").connect("pressed", get_tree(), "quit")
	get_node(menu_path + "Health/Dec").connect("pressed", self, "crement", ["hp", -1])
	get_node(menu_path + "Health/Inc").connect("pressed", self, "crement", ["hp", 1])
	get_node(menu_path + "Balls/Dec").connect("pressed", self, "crement", ["balls", -1])
	get_node(menu_path + "Balls/Inc").connect("pressed", self, "crement", ["balls", 1])
	get_node(menu_path + "Play").grab_focus()
	add_child(reset_timer)
	reset_timer.connect("timeout", self, "unload_game")
	update_option_nodes()
	update_balls()
	randomize()
	var map_color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	used_colors.append(map_color)
	get_node("Game/TestMap").modulate = map_color
	get_node("Game/Camera2D").position = defCamPos

# Update UI when changing settings
func update_option_nodes():
	get_node(menu_path + "Health/HealthNum").text = str(max_hp)
	get_node(menu_path + "Balls/BallNum").text = str(max_balls)

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
		var ball = load("res://ball/ball.tscn").instance()
		ball.position = get_node("Game/TestMap/BallSpawns").get_child(i).position
		get_node("Game/Balls").add_child(ball)

# Set up game, wait for players
func load_game():
	state = "starting"
	set_msg("Press A/Enter to join (or begin if P1)", true)
	get_node("UILayer/Menu").hide()
	get_node("Game/Camera2D").position = defCamPos

# Signal player nodes to begin
func start_game():
	set_msg("", false)
	for p in players:
		p.node.is_enabled = true
	state = "playing"

# Reset and clear players/balls
func unload_game():
	state = "idle"
	reset_timer.stop()
	get_node("Game/Camera2D").position = defCamPos
	get_node("Game/Camera2D").zoom = Vector2(1, 1)
	set_msg("", false)
	players.clear()
	for p in get_node("Game/Players").get_children():
		p.queue_free()
	update_balls()
	for b in bars.get_children():
		b.queue_free()
	bars.columns = 1
	get_node("UILayer/Menu").show()
	get_node(menu_path + "Play").grab_focus()

# Create new player
func new_player(id):
	# Create player node and color
	var p_num = players.size()
	var new_player = load("res://player/player.tscn").instance()
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
		hp_bit.texture = load("res://main/hp.png")
		hp_bar.add_child(hp_bit)
	new_bar.add_child(hp_bar)
	bars.add_child(new_bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	# Add player node and data
	new_player.spawn_position = spawns.get_child(p_num).position
	new_player.spawn_rotation = spawns.get_child(p_num).rotation
	new_player.connect("hit", self, "on_player_hit")
	players.append({pad = id, hp = max_hp, color = new_color, hud = hp_bar, node = new_player})
	get_node("Game/Players").add_child(new_player)
	get_node("Game/Players").move_child(new_player, 0)

# Manage player health
func on_player_hit(p_num):
	if state != "playing":
		return
	players[p_num].hp -= 1
	if players[p_num].hp == 0:
		players[p_num].node.queue_free()
		if players[p_num].pad >= 0:
			Input.start_joy_vibration(players[p_num].pad, .2, .2, .3)
		if players.size() == 2:
			state = "ending"
			set_msg("Game ended!", true)
			reset_timer.start(3)
	var hp_bits = players[p_num].hud.get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(.3, .3, .3, .3)
		if players[p_num].hp > i:
			hp_bits[i].modulate = Color(1, 1, 1, 1)

# Check if a pad is already used
func is_new_pad(id):
	for p in players:
		if p.pad == id:
			return false
	return true

func _process(_delta):
	# Create player if sensed input
	if players.size() < 8 and state == "starting":
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, JOY_BUTTON_0) and is_new_pad(c):
					new_player(c)
	
	# Start game when player one presses start/enter
	if state == "starting" and players.size() > 1:
		if (players[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(players[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(players[0].pad >= 0 and Input.is_joy_button_pressed(players[0].pad, JOY_BUTTON_0)):
			start_game()
	
	# Center camera to average player position, zoom camera to always view all players
	if state != "idle" and players.size() > 0:
		var avg = Vector2()
		for player in get_node("Game/Players").get_children():
			avg.x += player.position.x
			avg.y += player.position.y
		get_node("Game/Camera2D").position = avg / players.size()
		
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for player in get_node("Game/Players").get_children():
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		var new_zoom_x = (abs(max_x - min_x) + 500) / OS.window_size.x
		var new_zoom_y = (abs(max_y - min_y) + 500) / OS.window_size.y
		var new_zoom = Vector2(max(new_zoom_x, new_zoom_y), max(new_zoom_x, new_zoom_y))
		new_zoom = Vector2(1, 1) if new_zoom < Vector2(1, 1) else new_zoom
		get_node("Game/Camera2D").zoom = get_node("Game/Camera2D").zoom.linear_interpolate(new_zoom, 0.05)
