extends Node

const VERSION = "Dev Build"
const MAX_HEALTH = 3
const MOVE_SPEED = 600

enum channels {
	UPDATE_OBJECTS,
	SET_PADDLE_INPUTS,
	JOIN_GAME,
	UNLOAD_GAME,
	CREATE_PADDLE,
	DAMAGE_PADDLE,
}

var is_playing = false
var map = "BigMap"
var user_name = ""
var user_id = 0

func reset():
	DiscordManager.leave_lobby()
	is_playing = false
