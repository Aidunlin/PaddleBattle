extends KinematicBody2D

signal hit(p)
onready var safe_timer = get_node("SafeTimer")
var safe = false

export var player_number = 0
export var pad_id = 0
var stick_dz = 0.2

var velocity = Vector2.ZERO
export var spawn_position = Vector2(0, 0)
export var spawn_rotation = 0
export var acceleration = 0.06
export var deceleration = 0.02
export var move_speed = 400
export var sprint_speed = 550
export var rotate_speed = 3.3

export var total_health = 4
var health = total_health

func _ready():
	safe_timer.start(4)
	safe = true
	position = spawn_position
	rotation = spawn_rotation

func _physics_process(delta):
	var input_vel = Vector2.ZERO
	var input_rot = 0
	
	# Manage inputs (-1 and -2 are keyboard controls)
	if pad_id == -1:
		input_vel.y = -float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_S))
		input_vel.x = -float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_D))
		input_rot = float(Input.is_key_pressed(KEY_H)) - float(Input.is_key_pressed(KEY_G))
		input_vel = input_vel.normalized()
		input_vel *= sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
		rotation += deg2rad(input_rot * rotate_speed)
	elif pad_id == -2:
		input_vel.y = -float(Input.is_key_pressed(KEY_UP)) + float(Input.is_key_pressed(KEY_DOWN))
		input_vel.x = -float(Input.is_key_pressed(KEY_LEFT)) + float(Input.is_key_pressed(KEY_RIGHT))
		input_rot = float(Input.is_key_pressed(KEY_KP_3)) - float(Input.is_key_pressed(KEY_KP_2))
		input_vel = input_vel.normalized()
		input_vel *= sprint_speed if Input.is_key_pressed(KEY_KP_1) else move_speed
		rotation += deg2rad(input_rot * rotate_speed)
	else:
		var left_x = Input.get_joy_axis(pad_id, JOY_AXIS_0)
		var left_y = Input.get_joy_axis(pad_id, JOY_AXIS_1)
		if abs(left_x) > stick_dz or abs(left_y) > stick_dz:
			var x_mult = 1 if left_x > 0 else -1
			var y_mult = 1 if left_y > 0 else -1
			input_vel = Vector2(x_mult * pow(left_x, 2), y_mult * pow(left_y, 2))
		input_vel *= sprint_speed if Input.is_joy_button_pressed(pad_id, 6) else move_speed
		var right_stick = Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_2), Input.get_joy_axis(pad_id, JOY_AXIS_3))
		if right_stick.length() > 0.7:
			rotation += get_angle_to(position + right_stick) * 0.1
	
	# Smoothify movement
	if input_vel.length() > 0:
		velocity = velocity.linear_interpolate(input_vel, acceleration)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, deceleration)
	
	# Manage collisions with balls
	var collision = move_and_collide(velocity * delta, false)
	if collision:
		if collision.collider.is_in_group("balls"):
			if velocity.length() > 0:
				collision.collider.apply_central_impulse(-collision.normal * velocity.length())
			else:
				collision.collider.apply_central_impulse(-collision.normal)
			velocity = velocity.bounce(collision.normal).normalized()
		else:
			velocity = velocity.bounce(collision.normal)
		if pad_id >= 0:
			Input.start_joy_vibration(pad_id, 0.2, 0.2, 0.1)

# Manage player damage, invincibiility, and resetting
func _on_back_entered(body):
	if body.is_in_group("balls") and not safe:
		emit_signal("hit", player_number)

# Reset player to defaults
func reset():
	velocity = Vector2.ZERO
	position = spawn_position
	health = total_health
	if pad_id >= 0:
		Input.start_joy_vibration(pad_id, 0.2, 0.2, 0.3)
	safe = true
	safe_timer.start(4)

# Damage player
func damage():
	health -= 1
	safe = true
	safe_timer.start(2)

func _on_SafeTimer_timeout():
	safe_timer.stop()
	safe = false
