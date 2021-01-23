extends KinematicBody2D

var is_owned_by_server: bool = false
var pad: int = -1
var keys: int = -1
var is_safe: bool = true
var is_dashing: bool = false
var can_dash: bool = true

var move_speed: int = 0
var velocity: Vector2 = Vector2()
var input_velocity: Vector2 = Vector2()
var input_rotation: float = 0

onready var safe_timer: Timer = get_node("SafeTimer")
onready var dash_timer: Timer = get_node("DashTimer")
onready var dash_reset_timer: Timer = get_node("DashResetTimer")


func _ready() -> void:
	safe_timer.start(3)


func _physics_process(delta: float) -> void:
	if is_owned_by_server:
		input_velocity = Vector2()
		input_rotation = 0
		if OS.is_window_focused():
			if keys >= 0:
				input_velocity.x = get_key(KEY_D, KEY_RIGHT) - get_key(KEY_A, KEY_LEFT)
				input_velocity.y = get_key(KEY_S, KEY_DOWN) - get_key(KEY_W, KEY_UP)
				input_velocity = input_velocity.normalized() * move_speed
				if bool(get_key(KEY_SHIFT, KEY_KP_1)) and input_velocity.length() > 0 and can_dash:
					can_dash = false
					is_dashing = true
					dash_timer.start(0.15)
				if is_dashing:
					input_velocity *= 3
				input_rotation = deg2rad((get_key(KEY_H, KEY_KP_3) - get_key(KEY_G, KEY_KP_2)) * 4)
			if pad >= 0:
				var left_stick: Vector2 = Vector2(Input.get_joy_axis(pad, 0), Input.get_joy_axis(pad, 1))
				var right_stick: Vector2 = Vector2(Input.get_joy_axis(pad, 2), Input.get_joy_axis(pad, 3))
				if left_stick.length() > 0.2:
					input_velocity.x = sign(left_stick.x) * pow(left_stick.x, 2)
					input_velocity.y = sign(left_stick.y) * pow(left_stick.y, 2)
					input_velocity *= move_speed
					if Input.is_joy_button_pressed(pad, JOY_L2) and can_dash:
						can_dash = false
						is_dashing = true
						dash_timer.start(0.15)
					if is_dashing:
						input_velocity *= 3
				if right_stick.length() > 0.7:
					input_rotation = get_angle_to(position + right_stick) * 0.1
	
	velocity = velocity.linear_interpolate(input_velocity, 0.06 if input_velocity.length() > 0 else 0.02)
	rotation += input_rotation
	
	var collision: KinematicCollision2D = move_and_collide(velocity * delta, false)
	if collision:
		if collision.collider.is_in_group("balls"):
			collision.collider.apply_central_impulse(-collision.normal * (200 if is_dashing else 100))
		else:
			velocity = velocity.bounce(collision.normal)
		get_node("/root/Main").call("vibrate", name)


func _on_Back_body_entered(body: Node2D) -> void:
	if body.is_in_group("balls") and not is_safe:
		get_node("/root/Main").call("hit", name)
		is_safe = true
		safe_timer.start(2)


func _on_SafeTimer_timeout() -> void:
	is_safe = false
	safe_timer.stop()


func _on_DashTimer_timeout() -> void:
	is_dashing = false
	dash_timer.stop()
	dash_reset_timer.start(1)


func _on_DashResetTimer_timeout():
	can_dash = true
	dash_reset_timer.stop()


# Set client data; called from Main
func inputs_from_client(input_data: Dictionary) -> void:
	input_velocity = input_data.velocity
	input_rotation = input_data.rotation
	if input_data.dash and can_dash:
		can_dash = false
		is_dashing = true
		dash_timer.start(0.15)
	if is_dashing:
		input_velocity *= 3


func get_key(key1: int, key2: int) -> int:
	return int(Input.is_key_pressed(key1 if keys == 0 else key2))
