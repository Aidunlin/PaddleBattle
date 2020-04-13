extends MarginContainer

var player_hp_bits = []
var player_pt_bits = []

# Change specified player's health bar
func _on_player_health(health, player):
	var hp_bits = player_hp_bits[player].get_children()
	for i in range(hp_bits.size()):
		hp_bits[i].modulate = Color(0.2,0.2,0.2,0.2)
		if health > i:
			hp_bits[i].modulate = Color(1,1,1,1)

# Increment player's points bar
func _on_give_point(player):
	var pt_bit = TextureRect.new()
	pt_bit.texture = load("res://img/point.png")
	player_pt_bits[player].add_child(pt_bit)

# Create new UI (health/point bars) for player
func _on_new_player(health, color):
	var new_bar = HBoxContainer.new()
	new_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	new_bar.modulate = color
	new_bar.alignment = BoxContainer.ALIGN_CENTER
	var bars_wrap = VBoxContainer.new()
	var hp_bar = HBoxContainer.new()
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
	bars_wrap.add_child(hp_bar)
	var pt_bar = HBoxContainer.new()
	var pt_texture = TextureRect.new()
	pt_texture.texture = load("res://img/points.png")
	pt_bar.add_child(pt_texture)
	var pt_bits = HBoxContainer.new()
	pt_bits.set("custom_constants/separation", -16)
	pt_bar.add_child(pt_bits)
	bars_wrap.add_child(pt_bar)
	new_bar.add_child(bars_wrap)
	$Bars.add_child(new_bar)
	$Bars.columns = $Bars.get_children().size() if $Bars.get_children().size() < 5 else 4
	player_hp_bits.append(hp_bits)
	player_pt_bits.append(pt_bits)
