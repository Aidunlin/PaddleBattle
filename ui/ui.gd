extends Control

signal map_switched()
signal start_requested()

const HP_TEXTURE = preload("res://ui/hp.png")

var bars = {}

onready var message_timer = $MessageTimer
onready var message_node = $Message
onready var bar_parent = $HUD/Bars
onready var menu_node = $Menu
onready var dev_wrap = $Menu/Main/DevWrap
onready var discord_0_button = $Menu/Main/DevWrap/Discord0
onready var discord_1_button = $Menu/Main/DevWrap/Discord1
onready var name_label = $Menu/Main/Name
onready var map_button = $Menu/Main/Map
onready var play_button = $Menu/Main/Play
onready var version_node = $Menu/Main/Version

func _ready():
	message_timer.connect("timeout", self, "set_message")
	discord_0_button.connect("pressed", self, "start_discord", ["0"])
	discord_1_button.connect("pressed", self, "start_discord", ["1"])
	map_button.connect("pressed", self, "switch_map")
	map_button.text = Game.map
	play_button.connect("pressed", self, "request_start")
	play_button.grab_focus()
	version_node.text = Game.VERSION
	if not Game.IS_DEV:
		start_discord("0")

func start_discord(instance):
	DiscordManager.Start(instance)
	dev_wrap.visible = false

func set_message(msg = "", time = 0):
	message_node.text = msg
	if time > 0:
		message_timer.start(time)
	elif msg != "" and not message_timer.is_stopped():
		message_timer.stop()
	message_node.visible = msg != ""

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
