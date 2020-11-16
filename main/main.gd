extends Node

onready var camera_spawn = $Game/TestMap/CameraSpawn.position
onready var spawns = $Game/TestMap/PlayerSpawns
onready var bars = $UI/HUD/Bars

var menu = "UI/Menu/Panel/Main/"
var state = "idle"
var health = 3
var balls = 10
var players = []
var colors = []
var ending_timer = Timer.new()

func _ready():
	get_node(menu + "Play").grab_focus()
	get_node(menu + "Play").connect("pressed", self, "load_game")
	get_node(menu + "LAN").connect("pressed", self, "switch_lan")
	get_node(menu + "Quit").connect("pressed", get_tree(), "quit")
	get_node(menu + "Health/Dec").connect("pressed", self, "crement", ["hp", -1])
	get_node(menu + "Health/Inc").connect("pressed", self, "crement", ["hp", 1])
	get_node(menu + "Balls/Dec").connect("pressed", self, "crement", ["balls", -1])
	get_node(menu + "Balls/Inc").connect("pressed", self, "crement", ["balls", 1])
	add_child(ending_timer)
	ending_timer.connect("timeout", self, "unload_game")
	update_balls()
	update_options()
	randomize()
	var color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	colors.append(color)
	$Game/TestMap.modulate = color
	$Game/Camera.position = camera_spawn

func _process(_delta):
	# Center camera to average player position, zoom camera to always view all players
	if state != "idle" and $Game/Players.get_child_count() > 0:
		var avg = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for player in $Game/Players.get_children():
			avg.x += player.position.x
			avg.y += player.position.y
			max_x = max(player.position.x, max_x)
			min_x = min(player.position.x, min_x)
			max_y = max(player.position.y, max_y)
			min_y = min(player.position.y, min_y)
		avg /= $Game/Players.get_child_count()
		var zoom_x = (max(max_x - avg.x, avg.x - min_x) * 2 + 500) / OS.window_size.x
		var zoom_y = (max(max_y - avg.y, avg.y - min_y) * 2 + 500) / OS.window_size.y
		var zoom = Vector2(max(zoom_x, zoom_y), max(zoom_x, zoom_y))
		zoom = Vector2(1, 1) if zoom < Vector2(1, 1) else zoom
		$Game/Camera.position = avg
		$Game/Camera.zoom = $Game/Camera.zoom.linear_interpolate(zoom, 0.05)

func _input(_event):
	# Create player if sensed input
	if players.size() < 8 and state == "starting":
		if Input.is_key_pressed(KEY_ENTER) and is_new_pad(-1):
			new_player(-1)
		elif Input.is_key_pressed(KEY_KP_ENTER) and is_new_pad(-2):
			new_player(-2)
		else:
			for c in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(c, 0) and is_new_pad(c):
					new_player(c)

	# Start game when player one presses start/enter
	if state == "starting" and players.size() > 1:
		if (players[0].pad == -1 and Input.is_key_pressed(KEY_ENTER)) or \
		(players[0].pad == -2 and Input.is_key_pressed(KEY_KP_ENTER)) or \
		(players[0].pad >= 0 and Input.is_joy_button_pressed(players[0].pad, 0)):
			start_game()
	
	if state == "playing" or state == "starting":
		if Input.is_key_pressed(KEY_SHIFT) and Input.is_key_pressed(KEY_ESCAPE):
			unload_game()

func switch_lan():
	get_tree().change_scene("res://online/online.tscn")

# Increment/decrement values of options
func crement(item, x):
	if item == "hp":
		health = clamp(health + x, 1, 5)
	if item == "balls":
		balls = clamp(balls + x, 1, 10)
		update_balls()
	update_options()

# Reset all the balls
func update_balls():
	for ball in $Game/Balls.get_children():
		ball.queue_free()
	for i in balls:
		var ball = load("res://ball/ball.tscn").instance()
		ball.position = $Game/TestMap/BallSpawns.get_child(i).position
		$Game/Balls.add_child(ball)

# Update UI when changing settings
func update_options():
	get_node(menu + "Health/HealthNum").text = str(health)
	get_node(menu + "Balls/BallNum").text = str(balls)

# Set up game, wait for players
func load_game():
	state = "starting"
	set_msg("Press A/Enter to join (or begin if P1)", true)
	$UI/Menu.hide()
	$Game/Camera.position = camera_spawn

# Signal player nodes to begin
func start_game():
	set_msg("", false)
	for p in players:
		p.node.is_enabled = true
	state = "playing"

# Reset and clear players/balls
func unload_game():
	state = "idle"
	ending_timer.stop()
	$Game/Camera.position = camera_spawn
	$Game/Camera.zoom = Vector2(1, 1)
	set_msg("", false)
	players.clear()
	for player in $Game/Players.get_children():
		player.queue_free()
	update_balls()
	for bar in bars.get_children():
		bar.queue_free()
	bars.columns = 1
	$UI/Menu.show()
	get_node(menu + "Play").grab_focus()

# Create new player
func new_player(id):
	# Create player node and color
	var number = players.size()
	var player = load("res://player/player.tscn").instance()
	player.name = str(number)
	player.pad = id
	var color = colors[0]
	while colors.has(color):
		randomize()
		color = Color.from_hsv((randi() % 9 * 40.0) / 360.0, 1, 1)
	colors.append(color)
	player.modulate = color
	
	# Add new HP bar for player
	var bar = HBoxContainer.new()
	bar.size_flags_horizontal = HBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = color
	bar.alignment = BoxContainer.ALIGN_CENTER
	var hp = HBoxContainer.new()
	hp.set("custom_constants/separation", -18)
	for _x in range(health):
		var bit = TextureRect.new()
		bit.texture = load("res://main/hp.png")
		hp.add_child(bit)
	bar.add_child(hp)
	bars.add_child(bar)
	bars.columns = clamp(bars.get_children().size(), 1, 4)
	
	# Add player node and data
	player.spawn_position = spawns.get_child(number).position
	player.spawn_rotation = spawns.get_child(number).rotation
	player.connect("hit", self, "on_player_hit")
	players.append({pad = id, hp = health, color = color, hud = hp, node = player})
	$Game/Players.add_child(player)
	$Game/Players.move_child(player, 0)

# Set message text and visibility
func set_msg(msg, show):
	$UI/Msg/Panel/Message.text = msg
	$UI/Msg/Panel/Message.get_parent().get_parent().visible = show

# Manage player health
func on_player_hit(p_num):
	if state != "playing":
		return
	players[p_num].hp -= 1
	if players[p_num].hp == 0:
		players[p_num].node.queue_free()
		Input.start_joy_vibration(players[p_num].pad, .2, .2, .3)
		if players.size() == 2:
			state = "ending"
			set_msg("Game ended!", true)
			ending_timer.start(3)
	var bits = players[p_num].hud.get_children()
	for i in range(health):
		bits[i].modulate.a = 1.0 if players[p_num].hp > i else 0.1

# Check if a pad is already used
func is_new_pad(id):
	for player in players:
		if player.pad == id:
			return false
	return true
