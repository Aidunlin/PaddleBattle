extends Node2D

func _ready():
	randomize()
	var p1_color = Color.from_hsv(randf(), 1, 1)
	$Player.modulate = p1_color
	$CanvasLayer/HUD/Bars/HPBar/P1HP.modulate = p1_color
	
	randomize()
	var p2_color = Color.from_hsv(randf(), 1, 1)
	while p2_color == p1_color:
		randomize()
		p2_color = Color.from_hsv(randf(), 1, 1)
	$Player2.modulate = p2_color
	$CanvasLayer/HUD/Bars/HPBar/P2HP.modulate = p2_color
	
	randomize()
	var map_color = Color.from_hsv(randf(), 1, 1)
	while map_color == p1_color or map_color == p2_color:
		randomize()
		map_color = Color.from_hsv(randf(), 1, 1)
	$TestMap.modulate = map_color

func _process(_delta):
	$Camera2D.position.x = ($Player.position.x - $Player2.position.x) / 2 + $Player2.position.x
	$Camera2D.position.y = ($Player.position.y - $Player2.position.y) / 2 + $Player2.position.y
