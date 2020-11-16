extends KinematicBody2D

signal hit(p)

var pad = 0
var is_enabled = false
var is_safe = true
var safe_timer = Timer.new()

var velocity = Vector2()
var input_velocity = Vector2()
var spawn_position = Vector2()
var spawn_rotation = 0
var move_speed = 500
var rotation_speed = 4

func _ready():
	add_child(safe_timer)
	safe_timer.connect("timeout", self, "safe_ended")
	safe_timer.start(4)
	position = spawn_position
	rotation = spawn_rotation

func _physics_process(delta):
	if !is_enabled:
		return
	input_velocity = Vector2()
	
	# Manage inputs (-1 and -2 are keyboard controls)
	if OS.is_window_focused() and pad < 0:
		input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
		input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
		input_velocity = input_velocity.normalized() * move_speed
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
	
	# Manage colls with balls
	var coll = move_and_collide(velocity * delta, false)
	if coll and is_enabled:
		if coll.collider.is_in_group("balls"):
			coll.collider.apply_central_impulse(-coll.normal * velocity.length())
		else:
			velocity = velocity.bounce(coll.normal)
		Input.start_joy_vibration(pad, 0.1, 0, 0.1)

# Return keypress from either key based on pad
func get_key(k1_key, k2_key):
	return float(Input.is_key_pressed(k2_key if pad == -2 else k1_key))

func back_entered(body):
	if body.is_in_group("balls") and !is_safe:
		emit_signal("hit", int(name))
		is_safe = true
		safe_timer.start(2)

# Remove invincibility
func safe_ended():
	is_safe = false
	safe_timer.stop()
