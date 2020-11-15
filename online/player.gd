extends KinematicBody2D

signal update(id, pos, rot)
var velocity = Vector2()
var accel = 0.05
var move_speed = 400
puppet var p_position = Vector2()
puppet var p_rotation = 0

func _physics_process(delta):
	if is_network_master():
		var input_vel = Vector2()
		if OS.is_window_focused():
			input_vel.y = -float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_S))
			input_vel.x = -float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_D))
			rotation += get_local_mouse_position().angle() * 0.15
		input_vel = input_vel.normalized() * move_speed
		velocity = velocity.linear_interpolate(input_vel if input_vel.length() > 0 else Vector2(), accel)
		var collision = move_and_collide(velocity * delta, false)
		if collision:
			velocity = velocity.bounce(collision.normal)
		rset("p_position", position)
		rset("p_rotation", rotation)
	else:
		position = p_position
		rotation = p_rotation
	
	if get_tree().is_network_server():
		emit_signal("update", int(name), position, rotation)
