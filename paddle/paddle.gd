extends KinematicBody2D

var is_safe: bool = true
var is_dashing: bool = false
var can_dash: bool = true

var velocity: Vector2 = Vector2()
var input_velocity: Vector2 = Vector2()
var input_rotation: float = 0

onready var safe_timer: Timer = get_node("SafeTimer")
onready var dash_timer: Timer = get_node("DashTimer")
onready var dash_reset_timer: Timer = get_node("DashResetTimer")


func _ready() -> void:
	safe_timer.start(3)


func _physics_process(delta: float) -> void:
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
func inputs(input_data: Dictionary) -> void:
	input_velocity = input_data.velocity
	input_rotation = input_data.rotation
	if input_data.dash and can_dash:
		can_dash = false
		is_dashing = true
		dash_timer.start(0.15)
	if is_dashing:
		input_velocity *= 3
