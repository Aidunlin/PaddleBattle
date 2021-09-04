extends Node

const BALL_SCENE = preload("res://scenes/ball.tscn")

var balls = []
var spawns = []

func create_balls():
	for i in spawns.size():
		var ball_node = BALL_SCENE.instance()
		balls.append({})
		ball_node.position = spawns[i].position
		add_child(ball_node)

func update_balls(new_balls):
	for ball_index in get_child_count():
		var ball_node = get_child(ball_index)
		if ball_node:
			if DiscordManager.IsLobbyOwner():
				ball_node.mode = RigidBody2D.MODE_CHARACTER
				if ball_node.position.length() > 4096:
					ball_node.queue_free()
					var new_ball_node = BALL_SCENE.instance()
					new_ball_node.position = spawns[ball_index].position
					add_child(new_ball_node)
				balls[ball_index].position = ball_node.position
			else:
				ball_node.mode = RigidBody2D.MODE_KINEMATIC
				balls[ball_index].position = new_balls[ball_index].position
				ball_node.position = balls[ball_index].position

func reset():
	for ball in get_children():
		ball.queue_free()
	balls.clear()
	spawns.clear()
