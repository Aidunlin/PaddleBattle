extends KinematicBody2D

signal hit(id)

onready var safe_timer = $SafeTimer

var playing_lan = false
var pad = 0
var enabled = false
var safe = true
var move_speed = 0

var velocity = Vector2()
var input_velocity = Vector2()
var input_rotation = 0
var client_input_velocity = Vector2()
var client_input_rotation = 0

func _ready():
	# Override when playing over LAN
	if get_tree().network_peer:
		playing_lan = true
		enabled = true
		safe = false
		pad = -1
	else:
		safe_timer.start(3)

func _physics_process(delta):
	if not enabled:
		return
	
	# Manage inputs
	if not playing_lan or name == "1":
		input_velocity = Vector2()
		input_rotation = 0
		if OS.is_window_focused() and pad < 0:
			input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
			input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
			input_velocity = input_velocity.normalized() * move_speed
			input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * 4)
		elif OS.is_window_focused():
			var l = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
			if l.length() > 0.2:
				input_velocity = Vector2(sign(l.x) * pow(l.x, 2), sign(l.y) * pow(l.y, 2)) * move_speed
			var r = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
			if r.length() > 0.7:
				input_rotation = get_angle_to(position + r) * 0.1
	else:
		input_velocity = client_input_velocity
		input_rotation = client_input_rotation
	
	rotation += input_rotation
	# Smoothify movement
	if input_velocity.length() > 0:
		velocity = velocity.linear_interpolate(input_velocity, 0.06)
	else:
		velocity = velocity.linear_interpolate(Vector2(), 0.02)
	
	# Detect collisions with balls/walls
	var collision = move_and_collide(velocity * delta, false)
	if collision and enabled:
		if collision.collider.is_in_group("balls"):
			collision.collider.apply_central_impulse(-collision.normal * 100)
		else:
			velocity = velocity.bounce(collision.normal)
		if pad >= 0:
			Input.start_joy_vibration(pad, 0.1, 0, 0.1)

func _input(_event):
	# Switch input method when playing over LAN
	if playing_lan and OS.is_window_focused():
		if pad == -1 and Input.is_joy_button_pressed(0, JOY_BUTTON_0):
			pad = 0
		elif pad == 0 and Input.is_key_pressed(KEY_ENTER):
			pad = -1

func inputs_from_client(input_data):
	client_input_velocity = input_data.velocity
	client_input_rotation = input_data.rotation

# Return keypress from either key based on pad
func get_key(key1, key2):
	if playing_lan:
		return float(Input.is_key_pressed(key1) or Input.is_key_pressed(key2))
	return float(Input.is_key_pressed(key2 if pad == -2 else key1))

# Hit detection and damage
func back_entered(body):
	if body.is_in_group("balls") and not safe:
		emit_signal("hit", int(name))
		safe = true
		safe_timer.start(2)

# Remove invincibility
func safe_ended():
	safe = false
	safe_timer.stop()
