extends Control

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
    add_child(hud)
    huds[data.name] = hud

func move_huds(paddle_names):
    for paddle in paddle_names:
        var hud = huds[paddle]
        var offset = Vector2(hud.rect_size.x / 2, 90)
        var paddle_pos = paddle_names[paddle].position
        hud.rect_position = paddle_pos - offset

func remove_hud(paddle):
    get_node(paddle).queue_free()
    huds.erase(paddle)

func reset():
    for hud in get_children():
        hud.queue_free()
    huds.clear()
