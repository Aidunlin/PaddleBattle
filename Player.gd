extends KinematicBody2D

signal hit(p)

var started = false
var pad = 0
var stick_dz = 0.2

onready var back = get_node("Back")
onready var safe_timer = get_node("SafeTimer")
var safe = false

var vel = Vector2.ZERO
var spawn_pos = Vector2(0, 0)
var spawn_rot = 0
var accel = 0.06
var decel = 0.02
var speed = {move = 400, sprint = 550, rot = 3.3}

func _ready():
	safe_timer.start(4)
	safe = true
	position = spawn_pos
	rotation = spawn_rot
	
	safe_timer.connect("timeout", self, "safe_ended")
	back.connect("body_exited", self, "back_entered")

func _physics_process(delta):
	if not started:
		return
	var input_vel = Vector2.ZERO
	var input_rot = 0
	
	# Manage inputs (-1 and -2 are keyboard controls)
	if pad == -1:
		input_vel.y = -float(Input.is_key_pressed(KEY_W)) + float(Input.is_key_pressed(KEY_S))
		input_vel.x = -float(Input.is_key_pressed(KEY_A)) + float(Input.is_key_pressed(KEY_D))
		input_rot = float(Input.is_key_pressed(KEY_H)) - float(Input.is_key_pressed(KEY_G))
		input_vel = input_vel.normalized()
		input_vel *= speed["sprint"] if Input.is_key_pressed(KEY_SHIFT) else speed["move"]
		rotation += deg2rad(input_rot * speed["rot"])
	elif pad == -2:
		input_vel.y = -float(Input.is_key_pressed(KEY_UP)) + float(Input.is_key_pressed(KEY_DOWN))
		input_vel.x = -float(Input.is_key_pressed(KEY_LEFT)) + float(Input.is_key_pressed(KEY_RIGHT))
		input_rot = float(Input.is_key_pressed(KEY_KP_3)) - float(Input.is_key_pressed(KEY_KP_2))
		input_vel = input_vel.normalized()
		input_vel *= speed["sprint"] if Input.is_key_pressed(KEY_KP_1) else speed["move"]
		rotation += deg2rad(input_rot * speed["rot"])
	else:
		var left_x = Input.get_joy_axis(pad, JOY_AXIS_0)
		var left_y = Input.get_joy_axis(pad, JOY_AXIS_1)
		if abs(left_x) > stick_dz or abs(left_y) > stick_dz:
			var x_mult = 1 if left_x > 0 else -1
			var y_mult = 1 if left_y > 0 else -1
			input_vel = Vector2(x_mult * pow(left_x, 2), y_mult * pow(left_y, 2))
		input_vel *= speed["sprint"] if Input.is_joy_button_pressed(pad, 6) else speed["move"]
		var right_stick = Vector2(Input.get_joy_axis(pad, JOY_AXIS_2), Input.get_joy_axis(pad, JOY_AXIS_3))
		if right_stick.length() > 0.7:
			rotation += get_angle_to(position + right_stick) * 0.1
	
	# Smoothify movement
	if input_vel.length() > 0:
		vel = vel.linear_interpolate(input_vel, accel)
	else:
		vel = vel.linear_interpolate(Vector2.ZERO, decel)
	
	# Manage colls with balls
	var coll = move_and_collide(vel * delta, false)
	if coll and started:
		if coll.collider.is_in_group("balls"):
			coll.collider.apply_central_impulse(coll.normal * -vel.length())
		vel = vel.bounce(coll.normal)
		if pad >= 0:
			Input.start_joy_vibration(pad, 0.2, 0.2, 0.1)

# Manage player damage, invincibiility, and resetting
func back_entered(body):
	if body.is_in_group("balls") and not safe:
		emit_signal("hit", int(name))

# Game has begun, allow player movement
func game_began():
	started = true

# Damage player
func damage():
	safe = true
	safe_timer.start(2)

# Remove invincibility
func safe_ended():
	safe = false
	safe_timer.stop()
