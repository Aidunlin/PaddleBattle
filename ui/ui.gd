extends Control

signal map_switched()
signal start_requested()
signal end_requested()

const HP_TEXTURE = preload("res://ui/hp.png")

var bars = {}
var invited_by

onready var message_timer = $MessageTimer
onready var message_node = $Message
onready var bar_parent = $HUD/Bars
onready var overlay = $Overlay
onready var invite_wrap = $InviteWrap
onready var invite_name = $InviteWrap/InviteView/Name
onready var accept_button = $InviteWrap/InviteView/Accept
onready var decline_button = $InviteWrap/InviteView/Decline
onready var menu_node = $Menu

onready var main_menu_node = $Menu/Main
onready var dev_wrap = $Menu/Main/DevWrap
onready var discord_0_button = $Menu/Main/DevWrap/Discord0
onready var discord_1_button = $Menu/Main/DevWrap/Discord1
onready var name_label = $Menu/Main/Name
onready var map_button = $Menu/Main/Map
onready var play_button = $Menu/Main/Play
onready var quit_button = $Menu/Main/Quit
onready var version_node = $Menu/Main/Version

onready var options_menu_node = $Menu/Options
onready var friends_list = $Menu/Options/FriendsWrap/Friends
onready var back_button = $Menu/Options/Back
onready var leave_button = $Menu/Options/Leave

func _ready():
	message_timer.connect("timeout", self, "set_message")
	accept_button.connect("pressed", self, "accept_invite")
	decline_button.connect("pressed", self, "decline_invite")
	discord_0_button.connect("pressed", self, "start_discord", ["0"])
	discord_0_button.grab_focus()
	discord_1_button.connect("pressed", self, "start_discord", ["1"])
	map_button.connect("pressed", self, "switch_map")
	map_button.text = Game.map
	play_button.connect("pressed", self, "request_start")
	quit_button.connect("pressed", get_tree(), "quit")
	version_node.text = Game.VERSION
	back_button.connect("pressed", self, "toggle_options")
	leave_button.connect("pressed", self, "request_end")
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

func toggle_options():
	overlay.visible = not overlay.visible
	options_menu_node.visible = not options_menu_node.visible
	if options_menu_node.visible:
		back_button.grab_focus()

class CustomSorter:
	static func sort_ascending(a, b):
		var compare_arr = [a.username.to_lower(), b.username.to_lower()]
		compare_arr.sort()
		return compare_arr[0] == a.username.to_lower()

func update_friends():
	for friend in friends_list.get_children():
		friend.queue_free()
	var friends = DiscordManager.GetRelationships()
	if friends:
		friends.sort_custom(CustomSorter, "sort_ascending")
		for friend in friends:
			var friend_button = Button.new()
			friend_button.text = friend.username
			friend_button.connect("pressed", DiscordManager, "SendInvite", [friend.id])
			friends_list.add_child(friend_button)

func show_invite(user_id, username):
	if not Game.is_playing:
		invited_by = user_id
		invite_name.text = "Invited by " + username
		invite_wrap.show()

func accept_invite():
	invite_wrap.hide()
	DiscordManager.AcceptInvite(invited_by)

func decline_invite():
	invite_wrap.hide()

func switch_map():
	emit_signal("map_switched")

func request_start():
	emit_signal("start_requested")

func request_end():
	emit_signal("end_requested")

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
	overlay.hide()
	main_menu_node.show()
	options_menu_node.hide()
	play_button.grab_focus()
	set_message(msg, 3)
