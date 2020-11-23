extends KinematicBody2D

signal hit(id)

onready var safe_timer = $SafeTimer

var playing_lan: bool = false
var is_server: bool = true
var pad: int = -1
var keys: int = -1
var enabled: bool = true
var safe: bool = true
var move_speed: int = 0

var velocity: Vector2 = Vector2()
var input_velocity: Vector2 = Vector2()
var input_rotation: float = 0
var client_velocity: Vector2 = Vector2()
var client_rotation: float = 0

func _ready():
	# Override when playing over LAN
	if get_tree().network_peer:
		playing_lan = true
		if not get_tree().is_network_server():
			is_server = false
		enabled = true
		safe = false
	else:
		safe_timer.start(3)

func _physics_process(delta):
	if not enabled:
		return
	
	# Manage inputs
	if not playing_lan or is_server:
		input_velocity = Vector2()
		input_rotation = 0
		if OS.is_window_focused():
			if keys >= 0:
				input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
				input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
				input_velocity = input_velocity.normalized() * move_speed
				input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * 4)
			if pad >= 0:
				var left_stick = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
				var right_stick = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
				if left_stick.length() > 0.2:
					input_velocity.x = sign(left_stick.x) * pow(left_stick.x, 2)
					input_velocity.y = sign(left_stick.y) * pow(left_stick.y, 2)
					input_velocity *= move_speed
				if right_stick.length() > 0.7:
					input_rotation = get_angle_to(position + right_stick) * 0.1
	else:
		input_velocity = client_velocity
		input_rotation = client_rotation
	rotation += input_rotation
	
	# Smoothify movement
	velocity = velocity.linear_interpolate(input_velocity, 0.06 if input_velocity.length() > 0 else 0.02)
	
	# Detect collisions with balls/walls
	var collision: KinematicCollision2D = move_and_collide(velocity * delta, false)
	if collision and enabled:
		if collision.collider.is_in_group("balls"):
			collision.collider.apply_central_impulse(-collision.normal * 100)
		else:
			velocity = velocity.bounce(collision.normal)
		if not playing_lan or is_server:
			if pad >= 0:
				Input.start_joy_vibration(pad, 0.1, 0, 0.1)
		elif has_node("/root/Main"):
			get_node("/root/Main").rpc_id(int(name), "vibrate")

# Set client data; called from Main
func inputs_from_client(input_data: Dictionary):
	client_velocity = input_data.velocity
	client_rotation = input_data.rotation

# Return keypress from either key
func get_key(key1: int, key2: int) -> int:
	return int(Input.is_key_pressed(key1 if keys == 0 else key2))

# Hit detection and damage
func back_entered(body: Node2D):
	if body.is_in_group("balls") and not safe:
		emit_signal("hit", int(name))
		safe = true
		safe_timer.start(2)

# Remove invincibility
func safe_ended():
	safe = false
	safe_timer.stop()
