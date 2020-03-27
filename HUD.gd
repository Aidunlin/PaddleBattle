extends MarginContainer

onready var p1_bits = $Bars/HPBar/P1HP/Bits
onready var p2_bits = $Bars/HPBar/P2HP/Bits
var p1_total_health = 0
var p2_total_health = 0

# Create HP bits
func _ready():
	for _x in range(p1_total_health):
		var new_bit = TextureRect.new()
		new_bit.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		new_bit.texture = load("res://img/hp-bit.png")
		p1_bits.add_child(new_bit)
	for _x in range(p1_total_health):
		var new_bit = TextureRect.new()
		new_bit.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		new_bit.texture = load("res://img/hp-bit.png")
		p2_bits.add_child(new_bit)

# Change HP bits based on player health
func _on_player_health(health, player):
	if player == 1:
		for i in range(p1_bits.get_children().size()):
			p1_bits.get_children()[i].modulate = Color(1,1,1,1)
			if not health > i:
				p1_bits.get_children()[i].modulate = Color(0.2,0.2,0.2,0.2)
	if player == 2:
		for i in range(p2_bits.get_children().size()):
			p2_bits.get_children()[i].modulate = Color(1,1,1,1)
			if not health > i:
				p2_bits.get_children()[i].modulate = Color(0.2,0.2,0.2,0.2)

# Set total number of HP bits
func _on_player_total_health(total_health, player):
	if player == 1:
		p1_total_health = total_health
	if player == 2:
		p2_total_health = total_health

# 
func _on_player_death(deaths, player):
	if player == 1:
		$Bars/DeathBar/P1D/Deaths.text = str(deaths)
	if player == 2:
		$Bars/DeathBar/P2D/Deaths.text = str(deaths)
