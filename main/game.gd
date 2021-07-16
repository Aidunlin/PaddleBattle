extends Node

const VERSION = "Dev Build"
const MAX_HEALTH = 3
const MOVE_SPEED = 500

enum Channels {
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
var username = ""
var user_id = 0

func is_lobby_owner():
	return DiscordManager.IsLobbyOwner()

func reset():
	if is_lobby_owner():
		DiscordManager.DeleteLobby()
	else:
		DiscordManager.LeaveLobby()
	is_playing = false
