extends KinematicBody2D

signal update(id, pos, rot)

var velocity = Vector2()
var input_velocity = Vector2()
var move_speed = 500
var using_pad = false

puppet var puppet_position = Vector2()
puppet var puppet_rotation = 0

func _physics_process(delta):
	if is_network_master():
		input_velocity = Vector2()
		
		# Manage inputs
		if OS.is_window_focused() and not using_pad:
			input_velocity.y = -float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_S))
			input_velocity.x = -float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_D))
			input_velocity = input_velocity.normalized() * move_speed
			rotation += get_local_mouse_position().angle() * 0.1
		elif OS.is_window_focused():
			var l = Vector2(Input.get_joy_axis(0, 0), Input.get_joy_axis(0, 1))
			if l.length() > 0.2:
				input_velocity = Vector2(sign(l.x) * pow(l.x, 2), sign(l.y) * pow(l.y, 2)) * move_speed
			var r = Vector2(Input.get_joy_axis(0, 2), Input.get_joy_axis(0, 3))
			if r.length() > 0.7:
				rotation += get_angle_to(position + r) * 0.1
		
		# Smoothify movement
		if input_velocity.length() > 0:
			velocity = velocity.linear_interpolate(input_velocity, 0.06)
		else:
			velocity = velocity.linear_interpolate(Vector2(), 0.02)
		
		# Manage colls with balls
		var coll = move_and_collide(velocity * delta, false)
		if coll:
			if coll.collider.is_in_group("balls"):
				coll.collider.apply_central_impulse(-coll.normal * velocity.length())
			else:
				velocity = velocity.bounce(coll.normal)
			if using_pad:
				Input.start_joy_vibration(0, 0.1, 0, 0.1)
		
		rset_unreliable("puppet_position", position)
		rset_unreliable("puppet_rotation", rotation)
	else:
		position = puppet_position
		rotation = puppet_rotation
	
	emit_signal("update", int(name), position, rotation)

func _input(_event):
	if not using_pad and Input.is_joy_button_pressed(0, JOY_START):
		using_pad = true
	elif using_pad and Input.is_key_pressed(KEY_ENTER):
		using_pad = false
