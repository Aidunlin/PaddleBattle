extends RigidBody2D


func _ready():
	randomize()
	modulate = Color(randf(), randf(), randf())
