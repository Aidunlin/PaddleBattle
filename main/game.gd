extends Node

const VERSION = "Dev Build"
const MAX_HEALTH = 3
const MOVE_SPEED = 500

const IS_DEV = true

enum Channels {
	UPDATE_OBJECTS,
	CHECK_CLIENT,
	START_CLIENT_GAME,
	UNLOAD_GAME,
	CREATE_PADDLE,
	SET_PADDLE_INPUTS,
	VIBRATE_PAD,
	DAMAGE_PADDLE,
}

var is_playing = false
var username = ""
var map = "BigMap"
var peer_id = 0

func is_server():
	return DiscordManager.IsLobbyOwner()

func setup_server():
	DiscordManager.CreateLobby()

func setup_client():
	pass

func reset():
	if is_server():
		DiscordManager.DeleteLobby()
	else:
		DiscordManager.LeaveLobby()
	is_playing = false
