extends KinematicBody2D

export var move_speed = 250
export var sprint_speed = 350
export var acceleration = 0.05
export var friction = 0.01
var velocity = Vector2.ZERO

func _ready():
	randomize()
	modulate = Color(randf(), randf(), randf())

func _physics_process(delta):
	var input_velocity = Vector2.ZERO
	input_velocity.x += float(Input.is_action_pressed("ui_right"))
	input_velocity.x -= float(Input.is_action_pressed("ui_left"))
	input_velocity.y += float(Input.is_action_pressed("ui_down"))
	input_velocity.y -= float(Input.is_action_pressed("ui_up"))
	
	if Input.is_action_pressed("ui_shift"):
		input_velocity = input_velocity.normalized() * sprint_speed
	else:
		input_velocity = input_velocity.normalized() * move_speed
	
	if input_velocity.length() > 0:
		velocity = velocity.linear_interpolate(input_velocity, acceleration)
	else:
		velocity = velocity.linear_interpolate(Vector2.ZERO, friction)
	
	velocity = move_and_slide(velocity)
	
	var coll_info = move_and_collide(velocity * delta)
	if coll_info:
		velocity = velocity.bounce(coll_info.normal)
	
	rotation += get_local_mouse_position().angle() * 0.1
