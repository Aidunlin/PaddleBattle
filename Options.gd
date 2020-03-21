extends Control

signal rotateType(id)

func _ready():
	hide()

func _process(_delta):
	if Input.is_action_just_released("ui_cancel"):
		visible = !visible


func _on_Button_pressed():
	hide()


func _on_OptionButton_item_selected(id):
	emit_signal("rotateType", id)
