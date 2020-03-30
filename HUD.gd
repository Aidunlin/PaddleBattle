extends MarginContainer

func _on_player_health(health, player):
	var hp_bits = $Bars.get_children()[player].get_children()[0].get_children()[1].get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(0.2,0.2,0.2,0.2)
		if health > i:
			hp_bits[i].modulate = Color(1,1,1,1)

func _on_give_point(player):
	var pt_bit = TextureRect.new()
	pt_bit.texture = load("res://img/point.png")
	$Bars.get_children()[player].get_children()[1].get_children()[1].add_child(pt_bit)

func _on_new_player(health, color):
	var new_bar = VBoxContainer.new()
	new_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	new_bar.modulate = color
	var hp_bar = HBoxContainer.new()
	hp_bar.alignment = BoxContainer.ALIGN_CENTER
	var hp_texture = TextureRect.new()
	hp_texture.texture = load("res://img/hp.png")
	hp_bar.add_child(hp_texture)
	var hp_bits = HBoxContainer.new()
	hp_bits.set("custom_constants/separation", -18)
	for _x in range(health):
		var hp_bit = TextureRect.new()
		hp_bit.texture = load("res://img/hp-bit.png")
		hp_bits.add_child(hp_bit)
	hp_bar.add_child(hp_bits)
	new_bar.add_child(hp_bar)
	var pts_bar = HBoxContainer.new()
	pts_bar.alignment = BoxContainer.ALIGN_CENTER
	var pts_texture = TextureRect.new()
	pts_texture.texture = load("res://img/points.png")
	pts_bar.add_child(pts_texture)
	var pts = HBoxContainer.new()
	pts.set("custom_constants/separation", -16)
	pts_bar.add_child(pts)
	new_bar.add_child(pts_bar)
	$Bars.add_child(new_bar)
