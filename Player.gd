extends KinematicBody2D

signal health(health, player, dir)
signal death(deaths, player)
export var player_number = 1
var velocity = Vector2.ZERO
var invincible = false
var health = 5
var deaths = 0

func _physics_process(delta):
	var input_vel = Vector2.ZERO
	
	if player_number == 1:
		input_vel.y -= float(Input.is_action_pressed("p1_up"))
		input_vel.y += float(Input.is_action_pressed("p1_down"))
		input_vel.x -= float(Input.is_action_pressed("p1_left"))
		input_vel.x += float(Input.is_action_pressed("p1_right"))
		input_vel = input_vel.normalized()
		if Input.is_action_pressed("p1_sprint"):
			input_vel *= 350
		else:
			input_vel *= 250
		rotation += float(Input.is_action_pressed("p1_cw")) * 0.05
		rotation -= float(Input.is_action_pressed("p1_ccw")) * 0.05
	
	if player_number == 2:
		input_vel.y -= float(Input.is_action_pressed("p2_up"))
		input_vel.y += float(Input.is_action_pressed("p2_down"))
		input_vel.x -= float(Input.is_action_pressed("p2_left"))
		input_vel.x += float(Input.is_action_pressed("p2_right"))
		input_vel = input_vel.normalized()
		if Input.is_action_pressed("p2_sprint"):
			input_vel *= 350
		else:
			input_vel *= 250
		rotation += float(Input.is_action_pressed("p2_cw")) * 0.05
		rotation -= float(Input.is_action_pressed("p2_ccw")) * 0.05
	
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

# Set ball's sender to this player
func _on_body_entered(body):
	if body.is_in_group("balls"):
		pass

# Decrease health if not invincible or cause game over
func _on_back_entered(body):
	if body.is_in_group("balls") and not invincible:
		health -= 1
		emit_signal("health", health, player_number, -1)
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
	deaths += 1
	emit_signal("health", health, player_number, 1)
	emit_signal("death", deaths, player_number)
	invincible = true
	$Invincibility.start(5)
