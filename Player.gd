extends KinematicBody2D

signal health(health, dir)
var velocity = Vector2.ZERO
var invincible = false
var health = 5

func _physics_process(delta):
	var input_vel = Vector2.ZERO
	input_vel.x += float(Input.is_action_pressed("ui_right"))
	input_vel.x -= float(Input.is_action_pressed("ui_left"))
	input_vel.y += float(Input.is_action_pressed("ui_down"))
	input_vel.y -= float(Input.is_action_pressed("ui_up"))
	
	# Determines if sprinting or just moving
	if Input.is_action_pressed("ui_shift"):
		input_vel = input_vel.normalized() * 350
	else:
		input_vel = input_vel.normalized() * 250
	
	# Smooth acceleration/deceleration
	if input_vel.length() > 0:
		velocity = velocity.linear_interpolate(input_vel, 0.05)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, 0.01)
	
	velocity = move_and_slide(velocity)
	
	# Bounce off of walls
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.normal)
	
	rotation += get_local_mouse_position().angle() * 0.1

# Set ball's sender to this player
func _on_body_entered(body):
	if body.is_in_group("balls"):
		pass

# Decrease health if not invincible or cause game over
func _on_back_entered(body):
	if body.is_in_group("balls") and not invincible:
		health -= 1
		emit_signal("health", health, -1)
		if health < 1:
			reset()
			return
		$Invincibility.start(2)
		invincible = true

func _on_Invincibility_timeout():
	$Invincibility.stop()
	invincible = false

func reset():
	velocity = Vector2.ZERO
	position = Vector2.ZERO
	health = 5
	emit_signal("health", health, 1)
	invincible = true
	$Invincibility.start(5)
