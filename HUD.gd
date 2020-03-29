extends MarginContainer

func _on_player_health(health, player):
	var bits = $Bars.get_children()[player].get_children()[1].get_children()
	for i in range(bits.size()):
		bits[i].modulate = Color(0.2,0.2,0.2,0.2)
		if health > i:
			bits[i].modulate = Color(1,1,1,1)

func _on_new_player(health, color):
	var new_bar = HBoxContainer.new()
	
	var new_hp = TextureRect.new()
	new_hp.texture = load("res://img/hp.png")
	new_bar.add_child(new_hp)
	
	var new_bits = HBoxContainer.new()
	new_bits.set_name("Bits")
	new_bits.set("custom_constants/separation", -18)
	for _x in range(health):
		var new_bit = TextureRect.new()
		new_bit.texture = load("res://img/hp-bit.png")
		new_bits.add_child(new_bit)
	
	new_bar.add_child(new_bits, true)
	new_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	new_bar.modulate = color
	$Bars.add_child(new_bar)
