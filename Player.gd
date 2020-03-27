extends KinematicBody2D

signal health(health, player)
signal total_health(total_health, player)
signal death(deaths, player)
export var player_number = 1
var velocity = Vector2.ZERO
var invincible = false
export var acceleration = 0.06
export var deceleration = 0.02
export var move_speed = 450
export var sprint_speed = 600
export var rotate_speed = 0.05
export var total_health = 4
var health = total_health
var deaths = 0

func _ready():
	emit_signal("total_health", total_health, player_number)

func _physics_process(delta):
	var input_vel = Vector2.ZERO
	
	if player_number == 1:
		input_vel.y -= float(Input.is_action_pressed("p1_up"))
		input_vel.y += float(Input.is_action_pressed("p1_down"))
		input_vel.x -= float(Input.is_action_pressed("p1_left"))
		input_vel.x += float(Input.is_action_pressed("p1_right"))
		input_vel = input_vel.normalized()
		if Input.is_action_pressed("p1_sprint"):
			input_vel *= sprint_speed
		else:
			input_vel *= move_speed
		rotation += float(Input.is_action_pressed("p1_cw")) * rotate_speed
		rotation -= float(Input.is_action_pressed("p1_ccw")) * rotate_speed
	
	if player_number == 2:
		input_vel.y -= float(Input.is_action_pressed("p2_up"))
		input_vel.y += float(Input.is_action_pressed("p2_down"))
		input_vel.x -= float(Input.is_action_pressed("p2_left"))
		input_vel.x += float(Input.is_action_pressed("p2_right"))
		input_vel = input_vel.normalized()
		if Input.is_action_pressed("p2_sprint"):
			input_vel *= sprint_speed
		else:
			input_vel *= move_speed
		rotation += float(Input.is_action_pressed("p2_cw")) * rotate_speed
		rotation -= float(Input.is_action_pressed("p2_ccw")) * rotate_speed
	
	# Smooth acceleration/deceleration
	if input_vel.length() > 0:
		velocity = velocity.linear_interpolate(input_vel, acceleration)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, deceleration)
	
	# Bounce off of things
	var collision = move_and_collide(velocity * delta, false)
	if collision:
		if collision.collider.is_in_group("balls"):
			if velocity.length() > 0:
				collision.collider.apply_central_impulse(-collision.normal * abs(velocity.length()))
			else:
				collision.collider.apply_central_impulse(-collision.normal * 100)
		velocity = velocity.bounce(collision.normal)

# Decrease health if not invincible or cause game over
func _on_back_entered(body):
	if body.is_in_group("balls") and not invincible:
		health -= 1
		emit_signal("health", health, player_number)
		if health < 1:
			velocity = Vector2.ZERO
			position = Vector2.ZERO
			health = total_health
			deaths += 1
			emit_signal("health", health, player_number)
			emit_signal("death", deaths, player_number)
			invincible = true
			$Invincibility.start(5)
			return
		$Invincibility.start(2)
		invincible = true

func _on_Invincibility_timeout():
	$Invincibility.stop()
	invincible = false
