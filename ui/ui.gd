extends Control

signal start_game()
signal connect_to_server()
signal refresh_servers()

const HP_TEXTURE = preload("res://ui/hp.png")

var current_menu = "main"
var bars = {}

onready var message_node = $Message
onready var bar_parent = $HUD/Bars
onready var menu_node = $Menu
onready var main_menu = $Menu/Main
onready var version_node = $Menu/Main/Version
onready var play_button = $Menu/Main/Play
onready var name_input = $Menu/Main/NameWrap/Name
onready var join_button = $Menu/Main/Join
onready var quit_button = $Menu/Main/Quit
onready var options_menu = $Menu/Options
onready var health_dec_button = $Menu/Options/HealthWrap/Dec
onready var health_node = $Menu/Options/HealthWrap/Health
onready var health_inc_button = $Menu/Options/HealthWrap/Inc
onready var balls_dec_button = $Menu/Options/BallsWrap/Dec
onready var balls_node = $Menu/Options/BallsWrap/Balls
onready var balls_inc_button = $Menu/Options/BallsWrap/Inc
onready var open_lan_toggle = $Menu/Options/OpenLANWrap/OpenLAN
onready var small_map_toggle = $Menu/Options/SmallMapWrap/SmallMap
onready var start_button = $Menu/Options/Start
onready var options_back_button = $Menu/Options/Back
onready var join_menu = $Menu/Join
onready var session_parent = $Menu/Join/List
onready var refresh_button = $Menu/Join/Refresh
onready var ip_input = $Menu/Join/IPWrap/IP
onready var join_ip_button = $Menu/Join/IPWrap/Join
onready var join_back_button = $Menu/Join/Back
onready var message_timer = $MessageTimer

# Update UI with config data, connect buttons
func _ready():
	version_node.text = Game.VERSION
	name_input.text = Game.config.peer_name
	ip_input.text = Game.config.ip
	if Game.config.is_open_to_lan:
		open_lan_toggle.text = "ON"
	if Game.config.using_small_map:
		small_map_toggle.text = "ON"
	health_node.text = str(Game.config.max_health)
	balls_node.text = str(Game.config.ball_count)
	play_button.grab_focus()
	play_button.connect("pressed", self, "switch_menu", ["options"])
	join_button.connect("pressed", self, "switch_menu", ["join"])
	quit_button.connect("pressed", get_tree(), "quit")
	health_dec_button.connect("pressed", self, "crement", ["health", -1])
	health_inc_button.connect("pressed", self, "crement", ["health", 1])
	balls_dec_button.connect("pressed", self, "crement", ["balls", -1])
	balls_inc_button.connect("pressed", self, "crement", ["balls", 1])
	open_lan_toggle.connect("pressed", self, "toggle_lan")
	small_map_toggle.connect("pressed", self, "toggle_small_map")
	start_button.connect("pressed", self, "emit_signal", ["start_game"])
	options_back_button.connect("pressed", self, "switch_menu", ["main"])
	refresh_button.connect("pressed", self, "emit_signal", ["refresh_servers"])
	join_ip_button.connect("pressed", self, "emit_signal", ["connect_to_server", ""])
	join_back_button.connect("pressed", self, "switch_menu", ["main"])
	message_timer.connect("timeout", self, "set_message")

# Update message and timer
func set_message(new = "", time = 0):
	message_node.text = new
	if time > 0:
		message_timer.start(time)
	elif new != "" and not message_timer.is_stopped():
		message_timer.stop()

# Increment or decrement option
func crement(which, value = 0):
	if which == "health":
		Game.config.max_health = int(clamp(Game.config.max_health + value, 1, 5))
		health_node.text = str(Game.config.max_health)
	elif which == "balls":
		Game.config.ball_count = int(clamp(Game.config.ball_count + value, 1, 10))
		balls_node.text = str(Game.config.ball_count)

# Switch menu, grab focus of button
func switch_menu(to):
	main_menu.visible = false
	options_menu.visible = false
	join_menu.visible = false
	if to == "main":
		main_menu.visible = true
		if current_menu == "options":
			play_button.grab_focus()
		elif current_menu == "join":
			join_button.grab_focus()
	elif to == "options":
		if name_input.text == "":
			set_message("Invalid name", 3)
			name_input.grab_focus()
			main_menu.visible = true
			return
		options_menu.visible = true
		start_button.grab_focus()
	elif to == "join":
		if name_input.text == "":
			set_message("Invalid name", 3)
			name_input.grab_focus()
			main_menu.visible = true
			return
		join_menu.visible = true
		join_back_button.grab_focus()
	current_menu = to
	emit_signal("refresh_servers")

# Self-explanatory
func toggle_inputs(disable):
	refresh_button.disabled = disable
	for session in session_parent.get_children():
		session.get_child(1).disabled = disable
	ip_input.editable = not disable
	join_ip_button.disabled = disable
	join_back_button.disabled = disable

# Self-explanatory
func toggle_lan():
	Game.config.is_open_to_lan = not Game.config.is_open_to_lan
	if Game.config.is_open_to_lan:
		open_lan_toggle.text = "ON"
	else:
		open_lan_toggle.text = "OFF"

# Self-explanatory
func toggle_small_map():
	Game.config.using_small_map = not Game.config.using_small_map
	if Game.config.using_small_map:
		small_map_toggle.text = "ON"
	else:
		small_map_toggle.text = "OFF"

# Create new server UI
func new_server(ip, server_name):
	var new_session = HBoxContainer.new()
	new_session.name = ip
	new_session.set("custom_constants/separation", 8)
	var new_label = Label.new()
	new_label.text = server_name
	new_label.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	var new_button = Button.new()
	new_button.text = "Join"
	new_button.connect("pressed", self, "emit_signal", ["connect_to_server", ip])
	new_session.add_child(new_label)
	new_session.add_child(new_button)
	session_parent.add_child(new_session)

# Create HUD for new player
func create_bar(data, count):
	var bar = VBoxContainer.new()
	bar.name = data.name
	bar.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = data.color
	bar.alignment = BoxContainer.ALIGN_CENTER
	var label = Label.new()
	label.text = data.name
	label.align = Label.ALIGN_CENTER
	bar.add_child(label)
	var hp_bar = HBoxContainer.new()
	hp_bar.alignment = BoxContainer.ALIGN_CENTER
	hp_bar.set("custom_constants/separation", -20)
	for i in Game.config.max_health:
		var bit = TextureRect.new()
		bit.texture = HP_TEXTURE
		if data.health <= i:
			bit.modulate.a = 0.1
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bar_parent.add_child(bar)
	bar_parent.columns = count + 1
	bars[data.name] = hp_bar

# Update health bar
func update_bar(paddle, health):
	for i in Game.config.max_health:
		if health > i:
			bars[paddle].get_child(i).modulate.a = 1.0
		else:
			bars[paddle].get_child(i).modulate.a = 0.1

# Self-explanatory
func reset(msg):
	bars.clear()
	bar_parent.columns = 1
	menu_node.show()
	toggle_inputs(false)
	switch_menu(current_menu)
	set_message(msg, 3)
