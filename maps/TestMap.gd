extends Node2D

func _ready():
	randomize()
	modulate = Color(randf(), randf(), randf())
