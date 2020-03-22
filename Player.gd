extends KinematicBody2D

export var moveSpeed = 400
export var acceleration = 0.1
export var friction = 0.05
var velocity = Vector2.ZERO

func _physics_process(_delta):
	var input_velocity = Vector2.ZERO
	input_velocity.x += float(Input.is_action_pressed("ui_right"))
	input_velocity.x -= float(Input.is_action_pressed("ui_left"))
	input_velocity.y += float(Input.is_action_pressed("ui_down"))
	input_velocity.y -= float(Input.is_action_pressed("ui_up"))
	input_velocity = input_velocity.normalized() * moveSpeed
	
	if input_velocity.length() > 0:
		velocity = velocity.linear_interpolate(input_velocity, acceleration)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, friction)

	velocity = move_and_slide(velocity)
	
	rotation += get_local_mouse_position().angle() * 0.1
