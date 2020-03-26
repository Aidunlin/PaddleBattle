extends Node2D

func _ready():
	# Random color for player/HUD and walls
	randomize()
	var randColor = Color.from_hsv(randf(), 1, 1)
	$Player.modulate = randColor
	$CanvasLayer/HUD/HPBar.modulate = randColor
	$TestMap.modulate = Color.from_hsv(randf(), 1, 1)
