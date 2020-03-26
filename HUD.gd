extends MarginContainer

onready var p1_bits = $Bars/HPBar/P1HP/Bits.get_children()
onready var p2_bits = $Bars/HPBar/P2HP/Bits.get_children()

func _on_player_health(health, player, _dir):
	if player == 1:
		for i in range(p1_bits.size()):
			p1_bits[i].show()
			if not health > i:
				p1_bits[i].hide()
	if player == 2:
		for i in range(p2_bits.size()):
			p2_bits[i].show()
			if not health > i:
				p2_bits[i].hide()

func _on_player_death(deaths, player):
	if player == 1:
		$Bars/DeathBar/P1D/Deaths.text = str(deaths)
	if player == 2:
		$Bars/DeathBar/P2D/Deaths.text = str(deaths)
