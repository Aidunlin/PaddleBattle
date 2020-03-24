extends Camera2D

func _input(event):
	if event.is_action_pressed("ui_scroll_up"):
		zoom -= Vector2(0.2, 0.2)
	if event.is_action_pressed("ui_scroll_down"):
		zoom += Vector2(0.2, 0.2)
	if event.is_action_pressed("ui_middle_click"):
		zoom = Vector2(2, 2)
	if zoom > Vector2(5, 5):
		zoom = Vector2(5, 5)
	if zoom < Vector2(1, 1):
		zoom = Vector2(1, 1)
