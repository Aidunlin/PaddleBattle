extends Node2D

export (PackedScene) var Ball
export var balls = 8

func _ready():
	randomize()
	var colors = [Color.from_hsv(randf(), 1, 1), Color.from_hsv(randf(), 1, 1),
				  Color.from_hsv(randf(), 1, 1), Color.from_hsv(randf(), 1, 1)]
	
	$Player.modulate = colors[0]
	$CanvasLayer/HUD/Bars/TopBar/HPBar/P1HP.modulate = colors[0]
	
	$Player2.modulate = colors[1]
	$CanvasLayer/HUD/Bars/TopBar/HPBar/P2HP.modulate = colors[1]
	
	$Player3.modulate = colors[2]
	$CanvasLayer/HUD/Bars/BottomBar/HPBar/P3HP.modulate = colors[2]
	
	$Player4.modulate = colors[3]
	$CanvasLayer/HUD/Bars/BottomBar/HPBar/P4HP.modulate = colors[3]
	
	randomize()
	var map_color = Color.from_hsv(randf(), 1, 1)
	while colors.has(map_color):
		randomize()
		map_color = Color.from_hsv(randf(), 1, 1)
	$TestMap.modulate = map_color
	
	for _x in range(balls):
		var ball = Ball.instance()
		add_child(ball)

func _process(_delta):
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().reload_current_scene()
