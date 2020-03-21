extends Area2D

export var moveSpeed = 400
export var rotateSpeed = 8
var rotateType = 0

func _physics_process(delta):
	var velocity = Vector2()
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	velocity = velocity.normalized() * moveSpeed
	position += velocity * delta
	
	if rotateType == 0:
		var lookVector = get_global_mouse_position() - global_position
		global_rotation = atan2(lookVector.y, lookVector.x)
	elif rotateType == 1:
		if Input.is_action_pressed("ui_left"):
			global_rotation_degrees -= rotateSpeed
		if Input.is_action_pressed("ui_right"):
			global_rotation_degrees += rotateSpeed

func _on_Options_rotateType(id):
	rotateType = id
