extends KinematicBody2D

signal give_point(player)
signal health(health, player)
export var player_number = 0
export var pad_id = 0
export var spawn_position = Vector2(0, 0)
var velocity = Vector2.ZERO
var invincible = false
export var acceleration = 0.06
export var deceleration = 0.02
export var move_speed = 400
export var sprint_speed = 550
export var rotate_speed = 3.3
export var total_health = 4
var stick_dz = 0.2
var health = total_health
var deaths = 0

func _ready():
	add_to_group("players")
	$Invincibility.start(4)
	invincible = true

func _physics_process(delta):
	var input_vel = Vector2.ZERO
	var input_rot = 0
	if pad_id == -1:
		input_vel.y = -float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_S))
		input_vel.x = -float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_D))
		input_rot = float(Input.is_key_pressed(KEY_H)) - float(Input.is_key_pressed(KEY_G))
		input_vel = input_vel.normalized()
		input_vel *= sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	elif pad_id == -2:
		input_vel.y = -float(Input.is_key_pressed(KEY_UP)) + float(Input.is_key_pressed(KEY_DOWN))
		input_vel.x = -float(Input.is_key_pressed(KEY_LEFT)) + float(Input.is_key_pressed(KEY_RIGHT))
		input_rot = float(Input.is_key_pressed(KEY_KP_3)) - float(Input.is_key_pressed(KEY_KP_2))
		input_vel = input_vel.normalized()
		input_vel *= sprint_speed if Input.is_key_pressed(KEY_KP_1) else move_speed
	else:
		var ljoy_xaxis = Input.get_joy_axis(pad_id, JOY_AXIS_0)
		var ljoy_yaxis = Input.get_joy_axis(pad_id, JOY_AXIS_1)
		if abs(ljoy_xaxis) > stick_dz || abs(ljoy_yaxis) > stick_dz:
			var x_mult = 1 if ljoy_xaxis > 0 else -1
			var y_mult = 1 if ljoy_yaxis > 0 else -1
			input_vel = Vector2(x_mult * pow(ljoy_xaxis, 2), y_mult * pow(ljoy_yaxis, 2))
		input_rot = pow(Input.get_joy_axis(pad_id, JOY_AXIS_7), 2) - pow(Input.get_joy_axis(pad_id, JOY_AXIS_6), 2)
		input_vel *= sprint_speed if Input.is_joy_button_pressed(pad_id, 1) else move_speed
	
	rotation += deg2rad(input_rot * rotate_speed)
	if input_vel.length() > 0:
		velocity = velocity.linear_interpolate(input_vel, acceleration)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, deceleration)
	
	var collision = move_and_collide(velocity * delta, false)
	if collision:
		if collision.collider.is_in_group("balls"):
			collision.collider.new_sender(player_number)
			if velocity.length() > 0:
				collision.collider.apply_central_impulse(-collision.normal * abs(velocity.length()))
			else:
				collision.collider.apply_central_impulse(-collision.normal * 100)
			velocity = velocity.bounce(collision.normal).normalized()
		else:
			velocity = velocity.bounce(collision.normal)
		if pad_id >= 0:
			Input.start_joy_vibration(pad_id, 0.2, 0.2, 0.1)

func _on_back_entered(body):
	if body.is_in_group("balls") and not invincible:
		health -= 1
		emit_signal("health", health, player_number)
		invincible = true
		if health < 1:
			velocity = Vector2.ZERO
			position = spawn_position
			health = total_health
			deaths += 1
			if body.recent_senders[0] == player_number and body.recent_senders.size() > 1:
				emit_signal("give_point", body.recent_senders[1])
			elif body.recent_senders[0] != player_number:
				emit_signal("give_point", body.recent_senders[0])
			emit_signal("health", total_health, player_number)
			if pad_id >= 0:
				Input.start_joy_vibration(pad_id, 0.2, 0.2, 0.3)
			$Invincibility.start(4)
		else:
			$Invincibility.start(2)

func _on_Invincibility_timeout():
	$Invincibility.stop()
	invincible = false
