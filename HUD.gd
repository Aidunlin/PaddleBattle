extends MarginContainer

onready var hpbit = $HPBar/Bits/HPBit
onready var hpbit2 = $HPBar/Bits/HPBit2
onready var hpbit3 = $HPBar/Bits/HPBit3
onready var hpbit4 = $HPBar/Bits/HPBit4
onready var hpbit5 = $HPBar/Bits/HPBit5
onready var hpbits = [hpbit, hpbit2, hpbit3, hpbit4, hpbit5]

func _on_player_health(health, _dir):
	for i in range(hpbits.size()):
		hpbits[i].show()
		if not health > i:
			hpbits[i].hide()
