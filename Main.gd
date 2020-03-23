extends Node2D

func _input(event):
	if event.is_action_released("ui_cancel"):
		get_tree().reload_current_scene()
