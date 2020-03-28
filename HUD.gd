extends MarginContainer

onready var bits = [$Bars/TopBar/HPBar/P1HP/Bits,$Bars/TopBar/HPBar/P2HP/Bits,
					$Bars/BottomBar/HPBar/P3HP/Bits, $Bars/BottomBar/HPBar/P4HP/Bits]
var total_health = [0, 0, 0, 0]

func _ready():
	for p in total_health.size():
		for _x in range(total_health[p]):
			var new_bit = TextureRect.new()
			new_bit.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			new_bit.texture = load("res://img/hp-bit.png")
			bits[p].add_child(new_bit)

func _on_player_health(health, player):
	for i in range(bits[player].get_children().size()):
		bits[player].get_children()[i].modulate = Color(1,1,1,1)
		if not health > i:
			bits[player].get_children()[i].modulate = Color(0.2,0.2,0.2,0.2)

func _on_player_total_health(health, player):
	total_health[player] = health

func _on_player_death(deaths, player):
	if player == 0:
		$Bars/TopBar/DeathBar/P1D/Deaths.text = str(deaths)
	if player == 1:
		$Bars/TopBar/DeathBar/P2D/Deaths.text = str(deaths)
	if player == 2:
		$Bars/BottomBar/DeathBar/P3D/Deaths.text = str(deaths)
	if player == 3:
		$Bars/BottomBar/DeathBar/P3D/Deaths.text = str(deaths)
