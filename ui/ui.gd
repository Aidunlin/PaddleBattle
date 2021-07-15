extends Control

signal map_switched()
signal start_requested()

const HP_TEXTURE = preload("res://ui/hp.png")

var bars = {}
var current_menu = "main"

onready var message_timer = $MessageTimer
onready var message_node = $Message
onready var bar_parent = $HUD/Bars
onready var menu_node = $Menu

onready var main_menu_node = $Menu/Main
onready var dev_wrap = $Menu/Main/DevWrap
onready var discord_0_button = $Menu/Main/DevWrap/Discord0
onready var discord_1_button = $Menu/Main/DevWrap/Discord1
onready var name_label = $Menu/Main/Name
onready var map_button = $Menu/Main/Map
onready var play_button = $Menu/Main/Play
onready var join_button = $Menu/Main/Join
onready var version_node = $Menu/Main/Version

onready var join_menu_node = $Menu/Join
onready var friends_list = $Menu/Join/FriendsWrap/Friends
onready var back_button = $Menu/Join/Back

func _ready():
	message_timer.connect("timeout", self, "set_message")
	discord_0_button.connect("pressed", self, "start_discord", ["0"])
	discord_0_button.grab_focus()
	discord_1_button.connect("pressed", self, "start_discord", ["1"])
	map_button.connect("pressed", self, "switch_map")
	map_button.text = Game.map
	play_button.connect("pressed", self, "request_start")
	join_button.connect("pressed", self, "switch_menu", ["join"])
	version_node.text = Game.VERSION
	back_button.connect("pressed", self, "switch_menu", ["main"])
	if not OS.is_debug_build():
		start_discord("0")

func start_discord(instance):
	DiscordManager.Start(instance)
	dev_wrap.visible = false
	play_button.grab_focus()

func set_message(msg = "", time = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()
	message_node.visible = msg != ""

func update_friends():
	for friend in friends_list.get_children():
		friend.queue_free()
	var friends = DiscordManager.GetRelationships()
	for friend in friends:
		var friend_button = Button.new()
		friend_button.text = friend.username
		friend_button.connect("pressed", self, "set_message", ["Joining from the game is not ready yet", 3])
		friends_list.add_child(friend_button)
	if current_menu == "join":
		back_button.grab_focus()

func switch_menu(to):
	main_menu_node.visible = false
	join_menu_node.visible = false
	if to == "main":
		main_menu_node.visible = true
		join_button.grab_focus()
	elif to == "join":
		join_menu_node.visible = true
		back_button.grab_focus()
	current_menu = to

func switch_map():
	emit_signal("map_switched")

func request_start():
	emit_signal("start_requested")

func create_bar(data, count):
	var bar = VBoxContainer.new()
	bar.name = data.name
	bar.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	bar.modulate = data.color
	bar.alignment = BoxContainer.ALIGN_CENTER
	bar.set("custom_constants/separation", -4)
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
	play_button.grab_focus()
	set_message(msg, 3)
