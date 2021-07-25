extends Control

signal map_switched()
signal end_requested()

var invited_by = 0

onready var message_wrap = $MessageWrap
onready var message_view = $MessageWrap/MessageView
onready var overlay = $Overlay
onready var invite_wrap = $InviteWrap
onready var invite_name = $InviteWrap/InviteView/Name
onready var accept_button = $InviteWrap/InviteView/Accept
onready var decline_button = $InviteWrap/InviteView/Decline
onready var menu_node = $Menu

onready var main_menu_node = $Menu/Main
onready var discord_0_button = $Menu/Main/Discord0
onready var discord_1_button = $Menu/Main/Discord1
onready var name_label = $Menu/Main/Name
onready var map_button = $Menu/Main/Map
onready var play_button = $Menu/Main/Play
onready var quit_button = $Menu/Main/Quit
onready var version_node = $Menu/Main/Version

onready var options_menu_node = $Menu/Options
onready var friends_list = $Menu/Options/FriendsWrap/Friends
onready var refresh_button = $Menu/Options/Refresh
onready var back_button = $Menu/Options/Back
onready var leave_button = $Menu/Options/Leave

func _ready():
	accept_button.connect("pressed", self, "accept_invite")
	decline_button.connect("pressed", self, "decline_invite")
	discord_0_button.connect("pressed", self, "start_discord", ["0"])
	discord_0_button.grab_focus()
	discord_1_button.connect("pressed", self, "start_discord", ["1"])
	map_button.connect("pressed", self, "emit_signal", ["map_switched"])
	map_button.text = Game.map
	quit_button.connect("pressed", get_tree(), "quit")
	version_node.text = Game.VERSION
	refresh_button.connect("pressed", self, "update_friends")
	back_button.connect("pressed", self, "hide_options")
	leave_button.connect("pressed", self, "emit_signal", ["end_requested"])
	if not OS.is_debug_build():
		start_discord("0")

func start_discord(instance):
	DiscordManager.start(instance)
	discord_0_button.hide()
	discord_1_button.hide()
	play_button.grab_focus()

func add_message(msg = ""):
	var new_message = Label.new()
	new_message.text = msg
	message_view.add_child(new_message)
	message_view.move_child(new_message, 0)
	if message_view.get_child_count() > 5:
		message_view.get_child(message_view.get_child_count() - 1).queue_free()
	print("Message: ", msg)

func show_options():
	overlay.show()
	options_menu_node.show()
	back_button.grab_focus()
	update_friends()

func hide_options():
	overlay.hide()
	options_menu_node.hide()

class CustomSorter:
	static func sort_ascending(a, b):
		var compare_arr = [a.name.to_lower(), b.name.to_lower()]
		compare_arr.sort()
		return compare_arr[0] == a.name.to_lower()

func friend_pressed(button, id):
	DiscordManager.send_invite(id)
	button.find_next_valid_focus().grab_focus()
	button.queue_free()

func update_friends():
	for friend in friends_list.get_children():
		friend.queue_free()
	var friends = DiscordManager.get_relationships()
	if friends:
		friends.sort_custom(CustomSorter, "sort_ascending")
		for friend in friends:
			var friend_button = Button.new()
			friend_button.text = friend.name
			friend_button.connect("pressed", self, "friend_pressed", [friend_button, friend.id])
			friends_list.add_child(friend_button)

func show_invite(user_id, user_name):
	if not Game.is_playing:
		invited_by = user_id
		invite_name.text = "Invited by " + user_name
		invite_wrap.show()

func accept_invite():
	invite_wrap.hide()
	DiscordManager.accept_invite(invited_by)

func decline_invite():
	invite_wrap.hide()

func reset(msg):
	overlay.hide()
	main_menu_node.show()
	options_menu_node.hide()
	play_button.grab_focus()
	add_message(msg)
