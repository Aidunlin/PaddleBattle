extends Node

const VERSION = "Dev Build"
const MAX_HEALTH = 3
const MOVE_SPEED = 500

enum channels {
	UPDATE_OBJECTS,
	CHECK_MEMBER,
	JOIN_GAME,
	UNLOAD_GAME,
	CREATE_PADDLE,
	SET_PADDLE_INPUTS,
	VIBRATE_PAD,
	DAMAGE_PADDLE,
}

var is_playing = false
var map = "BigMap"
var user_name = ""
var user_id = 0

func reset():
	if DiscordManager.is_lobby_owner():
		DiscordManager.delete_lobby()
	else:
		DiscordManager.leave_lobby()
	is_playing = false
