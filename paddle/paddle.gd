extends KinematicBody2D

signal collided()
signal damaged()

var is_safe = true
var is_dashing = false
var can_dash = true

var velocity = Vector2()
var input_velocity = Vector2()
var input_rotation = 0.0

onready var back_node = $Back
onready var safe_timer = $SafeTimer
onready var dash_timer = $DashTimer
onready var dash_reset_timer = $DashResetTimer


func _ready():
	back_node.connect("body_entered", self, "back_collided")
	safe_timer.connect("timeout", self, "safe_timeout")
	dash_timer.connect("timeout", self, "dash_timeout")
	dash_reset_timer.connect("timeout", self, "dash_reset_timeout")
	safe_timer.start(3)


func _physics_process(delta):
	if input_velocity.length() > 0:
		velocity = velocity.linear_interpolate(input_velocity, 0.06)
	else:
		velocity = velocity.linear_interpolate(input_velocity, 0.02)
	rotation += input_rotation
	
	var collision = move_and_collide(velocity * delta, false)
	if collision:
		if collision.collider.is_in_group("balls"):
			if is_dashing:
				collision.collider.apply_central_impulse(-collision.normal * 300)
			else:
				collision.collider.apply_central_impulse(-collision.normal * 100)
		else:
			velocity = velocity.bounce(collision.normal)
		emit_signal("collided")


func back_collided(body):
	if body.is_in_group("balls") and not is_safe:
		emit_signal("damaged")
		is_safe = true
		safe_timer.start(2)


func safe_timeout():
	is_safe = false
	safe_timer.stop()


func dash_timeout():
	is_dashing = false
	dash_timer.stop()
	dash_reset_timer.start(0.65)


func dash_reset_timeout():
	can_dash = true
	dash_reset_timer.stop()


func inputs(data):
	input_velocity = data.velocity
	input_rotation = data.rotation
	if data.dash and can_dash:
		can_dash = false
		is_dashing = true
		dash_timer.start(0.15)
	if is_dashing:
		input_velocity *= 3
