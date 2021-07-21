extends Node

const BALL_TEXTURE = preload("res://ball/ball.png")
const BALL_SCENE = preload("res://ball/ball.tscn")

var balls = []
var spawns = []

func create_balls():
	for i in spawns.size():
		var ball_node = BALL_SCENE.instance()
		if DiscordManager.is_lobby_owner():
			balls.append({})
		else:
			ball_node = Sprite.new()
			ball_node.texture = BALL_TEXTURE
		ball_node.position = spawns[i].position
		add_child(ball_node)

func update_balls(new_balls):
	for ball_index in get_child_count():
		var ball_node = get_child(ball_index)
		if ball_node:
			if DiscordManager.is_lobby_owner():
				if ball_node.position.length() > 4096:
					ball_node.queue_free()
					var new_ball_node = BALL_SCENE.instance()
					new_ball_node.position = spawns[ball_index].position
					add_child(new_ball_node)
				balls[ball_index].position = ball_node.position
				balls[ball_index].rotation = ball_node.rotation
			else:
				ball_node.position = new_balls[ball_index].position
				ball_node.rotation = new_balls[ball_index].rotation

func reset():
	for ball in get_children():
		ball.queue_free()
	balls.clear()
