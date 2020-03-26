extends RigidBody2D

var wall_collide = false

func _ready():
	add_to_group("balls")

# Reset if escapes map and sets max velocity
func _integrate_forces(state):
	if abs(position.length()) > 5000:
		state.transform = Transform2D(0, Vector2(0, 0))
		state.linear_velocity = Vector2(0, 0)
	if state.linear_velocity.length() > 1000:
		state.linear_velocity = state.linear_velocity.normalized() * 1000

# Half-fix so ball doesn't go light-speed when pinned against wall
func _on_body_entered(body):
	if body.is_in_group("walls"):
		$StaticBody2D/CollisionShape2D.set_deferred("disabled", false)
		$WallCollide.start(0.02)
		wall_collide = true

func _on_WallCollide_timeout():
	$StaticBody2D/CollisionShape2D.set_deferred("disabled", true)
	wall_collide = false
