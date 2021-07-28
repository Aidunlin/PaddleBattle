extends KinematicBody2D

signal collided()
signal damaged()

var is_safe = true
var is_dashing = false
var was_dashing = false
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
	if DiscordManager.is_lobby_owner():
		velocity = velocity.linear_interpolate(input_velocity, 0.06)
		rotation += input_rotation
		var collision = move_and_collide(velocity * delta, false)
		if collision:
			if collision.collider.is_in_group("balls"):
				var modifier = 200 if is_dashing else 100
				collision.collider.apply_central_impulse(-collision.normal * modifier)
			else:
				velocity = velocity.bounce(collision.normal)
			emit_signal("collided")

func back_collided(body):
	if DiscordManager.is_lobby_owner() and body.is_in_group("balls") and not is_safe:
		emit_signal("damaged")
		safe_timer.start(2)
		is_safe = true

func safe_timeout():
	safe_timer.stop()
	if DiscordManager.is_lobby_owner():
		is_safe = false

func dash_timeout():
	dash_timer.stop()
	if DiscordManager.is_lobby_owner():
		is_dashing = false
		dash_reset_timer.start(0.2)

func dash_reset_timeout():
	dash_reset_timer.stop()
	if DiscordManager.is_lobby_owner():
		can_dash = true

func set_inputs(inputs):
	if DiscordManager.is_lobby_owner():
		input_velocity = inputs.velocity
		input_rotation = inputs.rotation
		if not inputs.dash:
			was_dashing = false
		if inputs.dash and can_dash and not was_dashing:
			can_dash = false
			is_dashing = true
			dash_timer.start(0.1)
		if is_dashing:
			was_dashing = true
			input_velocity *= 3
