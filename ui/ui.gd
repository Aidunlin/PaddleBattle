extends Control

signal map_switched()
signal start_requested()
signal connect_requested()

const HP_TEXTURE = preload("res://ui/hp.png")

var current_menu = "main"
var bars = {}

onready var message_node = $Message
onready var bar_parent = $HUD/Bars
onready var menu_node = $Menu
onready var main_menu = $Menu/Main
onready var play_button = $Menu/Main/Play
onready var name_input = $Menu/Main/NameWrap/Name
onready var join_button = $Menu/Main/Join
onready var quit_button = $Menu/Main/Quit
onready var version_node = $Menu/Main/FooterWrap/Version
onready var play_menu = $Menu/Play
onready var map_button = $Menu/Play/MapWrap/Map
onready var start_button = $Menu/Play/Start
onready var play_menu_back_button = $Menu/Play/Back
onready var join_menu = $Menu/Join
onready var server_parent = $Menu/Join/List
onready var refresh_button = $Menu/Join/Refresh
onready var join_ip_input = $Menu/Join/IPWrap/IP
onready var join_ip_button = $Menu/Join/JoinIP
onready var join_menu_back_button = $Menu/Join/Back
onready var message_timer = $MessageTimer

func _ready():
	version_node.text = Game.VERSION
	name_input.text = Game.config.peer_name
	join_ip_input.text = Game.config.ip
	map_button.text = Game.config.map
	play_button.grab_focus()
	play_button.connect("pressed", self, "switch_menu", ["play"])
	join_button.connect("pressed", self, "switch_menu", ["join"])
	quit_button.connect("pressed", get_tree(), "quit")
	map_button.connect("pressed", self, "switch_map")
	start_button.connect("pressed", self, "request_start")
	play_menu_back_button.connect("pressed", self, "switch_menu", ["main"])
	refresh_button.connect("pressed", self, "refresh_servers")
	join_ip_button.connect("pressed", self, "request_connect")
	join_menu_back_button.connect("pressed", self, "switch_menu", ["main"])
	message_timer.connect("timeout", self, "set_message")

func set_message(msg = "", time = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()
	message_node.visible = msg != ""

func switch_menu(new_menu):
	main_menu.visible = false
	play_menu.visible = false
	join_menu.visible = false
	if new_menu == "main":
		main_menu.visible = true
		if current_menu == "play":
			play_button.grab_focus()
		elif current_menu == "join":
			join_button.grab_focus()
	elif new_menu == "play":
		if name_input.text == "":
			set_message("Invalid name", 3)
			name_input.grab_focus()
			main_menu.visible = true
			return
		play_menu.visible = true
		start_button.grab_focus()
	elif new_menu == "join":
		if name_input.text == "":
			set_message("Invalid name", 3)
			name_input.grab_focus()
			main_menu.visible = true
			return
		join_menu.visible = true
		join_menu_back_button.grab_focus()
	current_menu = new_menu

func refresh_servers():
	for server in server_parent.get_children():
		server.queue_free()
	var servers = Network.get_servers()
	for ip in servers.keys():
		create_new_server(ip, servers[ip])

func toggle_inputs(disable):
	refresh_button.disabled = disable
	for server_node in server_parent.get_children():
		server_node.get_child(1).disabled = disable
	join_ip_input.editable = not disable
	join_ip_button.disabled = disable
	join_menu_back_button.disabled = disable

func switch_map():
	emit_signal("map_switched")

func create_new_server(ip, server_name):
	var new_server = HBoxContainer.new()
	new_server.name = ip
	new_server.set("custom_constants/separation", 8)
	var new_label = Label.new()
	new_label.text = server_name
	new_label.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	var new_button = Button.new()
	new_button.text = "Join"
	new_button.connect("pressed", self, "request_connect", [ip])
	new_server.add_child(new_label)
	new_server.add_child(new_button)
	server_parent.add_child(new_server)

func request_start():
	emit_signal("start_requested")

func request_connect(ip = ""):
	if ip == "":
		ip = join_ip_input.text
	emit_signal("connect_requested", ip)

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
	for i in Game.MAX_HEALTH:
		var bit = TextureRect.new()
		bit.texture = HP_TEXTURE
		if data.health <= i:
			bit.modulate.a = 0.1
		hp_bar.add_child(bit)
	bar.add_child(hp_bar)
	bar_parent.add_child(bar)
	bar_parent.columns = count + 1
	bars[data.name] = hp_bar

func update_bar(paddle, health):
	for i in Game.MAX_HEALTH:
		if health > i:
			bars[paddle].get_child(i).modulate.a = 1.0
		else:
			bars[paddle].get_child(i).modulate.a = 0.1

func remove_bar(paddle):
	bar_parent.get_node(paddle).queue_free()

func reset(msg):
	for bar in bar_parent.get_children():
		bar.queue_free()
	bars.clear()
	bar_parent.columns = 1
	menu_node.show()
	toggle_inputs(false)
	switch_menu(current_menu)
	set_message(msg, 3)
