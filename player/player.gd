extends KinematicBody2D

signal hit(id)
signal update(id, pos, rot)

var pad = 0
var enabled = false
var safe = true
var using_pad = false
var playing_lan = false
var is_master = true
var safe_timer = Timer.new()

var velocity = Vector2()
var input_velocity = Vector2()
var spawn_position = Vector2()
var spawn_rotation = 0
var move_speed = 500
var rotation_speed = 4

puppet var puppet_position = Vector2()
puppet var puppet_rotation = 0

func _ready():
	if get_tree().network_peer:
		if not is_network_master():
			is_master = false
	
	# Override when playing over LAN
	if playing_lan:
		enabled = true
		safe = false
		pad = -1
	else:
		position = spawn_position
		rotation = spawn_rotation
	
	add_child(safe_timer)
	safe_timer.connect("timeout", self, "safe_ended")

func _physics_process(delta):
	if not enabled:
		return
	
	# Manage inputs
	input_velocity = Vector2()
	if is_master:
		if OS.is_window_focused() and pad < 0:
			input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
			input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
			input_velocity = input_velocity.normalized() * move_speed
			if playing_lan:
				rotation += get_local_mouse_position().angle() * 0.1
			else:
				rotation_degrees += (get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * rotation_speed
		elif OS.is_window_focused():
			var l = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
			if l.length() > 0.2:
				input_velocity = Vector2(sign(l.x) * pow(l.x, 2), sign(l.y) * pow(l.y, 2)) * move_speed
			var r = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
			if r.length() > 0.7:
				rotation += get_angle_to(position + r) * 0.1
		
		# Smoothify movement
		if input_velocity.length() > 0:
			velocity = velocity.linear_interpolate(input_velocity, 0.06)
		else:
			velocity = velocity.linear_interpolate(Vector2(), 0.02)
		
		# Manage collisions with balls
		var collision = move_and_collide(velocity * delta, false)
		if collision and enabled:
			if collision.collider.is_in_group("balls"):
				collision.collider.apply_central_impulse(-collision.normal * velocity.length())
			else:
				velocity = velocity.bounce(collision.normal)
			if pad >= 0:
				Input.start_joy_vibration(pad, 0.1, 0, 0.1)
	
	# Sync position and rotation across network peers
	if get_tree().network_peer:
		if is_master:
			rset_unreliable("puppet_position", position)
			rset_unreliable("puppet_rotation", rotation)
		else:
			position = puppet_position
			rotation = puppet_rotation
		emit_signal("update", int(name), position, rotation)

func _input(_event):
	if playing_lan:
		if not using_pad and Input.is_joy_button_pressed(0, JOY_BUTTON_0):
			using_pad = true
			pad = 0
		elif using_pad and Input.is_key_pressed(KEY_ENTER):
			using_pad = false
			pad = -1

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
