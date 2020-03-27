extends RigidBody2D

var colliding = false
export var max_position = 3000
export var max_velocity = 1000

func _ready():
	add_to_group("balls")

# Reset if escapes map and sets max velocity
func _integrate_forces(state):
	if abs(position.length()) > max_position:
		state.transform = Transform2D(0, Vector2(0, 0))
		state.linear_velocity = Vector2(0, 0)
	if state.linear_velocity.length() > max_velocity:
		state.linear_velocity = state.linear_velocity.normalized() * max_velocity

# Half-fix so ball doesn't go light-speed when pinned against wall
func _on_body_entered(_body):
	$StaticBody2D/CollisionShape2D.set_deferred("disabled", false)
	$CollideTimer.start(0.02)
	colliding = true

func _on_collide_timeout():
	$StaticBody2D/CollisionShape2D.set_deferred("disabled", true)
	colliding = false
