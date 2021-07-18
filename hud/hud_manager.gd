extends Control

const HP_TEXTURE = preload("res://ui/hp.png")

var huds = {}

func create_hud(data):
	var hud = VBoxContainer.new()
	hud.name = data.name
	hud.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL
	hud.modulate = data.color
	hud.alignment = BoxContainer.ALIGN_CENTER
	hud.set("custom_constants/separation", -8)
	var label = Label.new()
	label.text = data.name
	label.align = Label.ALIGN_CENTER
	hud.add_child(label)
	var hp_hud = HBoxContainer.new()
	hp_hud.alignment = BoxContainer.ALIGN_CENTER
	hp_hud.set("custom_constants/separation", -20)
	for i in Game.MAX_HEALTH:
		var bit = TextureRect.new()
		bit.texture = HP_TEXTURE
		if data.health <= i:
			bit.modulate.a = 0.1
		hp_hud.add_child(bit)
	hud.add_child(hp_hud)
	add_child(hud)
	huds[data.name] = hp_hud

func move_huds(paddles):
	for paddle in paddles:
		var hud = huds[paddle].get_parent()
		var offset = Vector2(hud.rect_size.x / 2, 130)
		var paddle_pos = paddles[paddle].position
		hud.rect_position = paddle_pos - offset

func update_hud(paddle, health):
	for i in Game.MAX_HEALTH:
		if health > i:
			huds[paddle].get_child(i).modulate.a = 1.0
		else:
			huds[paddle].get_child(i).modulate.a = 0.1

func remove_hud(paddle):
	get_node(paddle).queue_free()
	huds.erase(paddle)

func reset():
	for hud in get_children():
		hud.queue_free()
	huds.clear()
