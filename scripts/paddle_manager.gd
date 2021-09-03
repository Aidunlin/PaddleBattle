extends Node

signal options_requested()
signal paddle_created()
signal paddle_damaged()
signal paddle_destroyed()
signal paddle_removed()

const PADDLE_SCENE = preload("res://scenes/paddle.tscn")

var input_list = {}
var used_inputs = []
var paddles = {}
var spawns = []

func _unhandled_input(_event):
	if Game.is_playing:
		if Input.is_key_pressed(KEY_ENTER) and not -1 in input_list.values():
			create_paddle_from_input(-1)
		for pad in Input.get_connected_joypads():
			if Input.is_joy_button_pressed(pad, JOY_BUTTON_0) and not pad in input_list.values():
				create_paddle_from_input(pad)
		if Input.is_key_pressed(KEY_ESCAPE) and -1 in used_inputs:
			emit_signal("options_requested")
			return
		for pad in used_inputs:
			if Input.is_joy_button_pressed(pad, JOY_START):
				emit_signal("options_requested")
				return

func create_paddle_from_input(pad):
	if not pad in used_inputs:
		var new_paddle_data = {
			"name": Game.user_name,
			"id": Game.user_id,
			"pad": pad,
		}
		used_inputs.append(pad)
		if DiscordManager.is_lobby_owner():
			create_paddle(new_paddle_data)
		else:
			DiscordManager.send_owner(new_paddle_data, true)

func create_paddle(data):
	var paddle_count = get_child_count()
	if paddle_count < spawns.size():
		var paddle_node = PADDLE_SCENE.instance()
		var name_count = 1
		for paddle in get_children():
			if data.name in paddle.name:
				name_count += 1
		var new_name = data.name
		if name_count > 1:
			new_name += str(name_count)
		paddle_node.name = new_name
		if "position" in data and "rotation" in data:
			paddle_node.position = data.position
			paddle_node.rotation = data.rotation
		else:
			paddle_node.position = spawns[paddle_count].position
			paddle_node.rotation = spawns[paddle_count].rotation
		if "color" in data:
			paddle_node.modulate = data.color
		else:
			paddle_node.modulate = Color.from_hsv(randf(), 0.8, 1)
		paddle_node.connect("damaged", self, "damage_paddle", [new_name])
		if Game.user_id == data.id and "pad" in data:
			input_list[new_name] = data.pad
		paddles[new_name] = {
			"id": data.id,
			"name": new_name,
			"position": paddle_node.position,
			"rotation": paddle_node.rotation,
			"color": paddle_node.modulate,
		}
		if "health" in data:
			paddles[new_name].health = data.health
		else:
			paddles[new_name].health = Game.MAX_HEALTH
		emit_signal("paddle_created", paddles[new_name])
		if DiscordManager.is_lobby_owner():
			var new_data = paddles[new_name].duplicate(true)
			if Game.user_id != data.id and "pad" in data:
				new_data.pad = data.pad
			DiscordManager.send_all(new_data, true)
		add_child(paddle_node)

func remove_paddle(paddle):
	paddles.erase(paddle)
	get_node(paddle).queue_free()
	emit_signal("paddle_removed", paddle)

func remove_paddles(id):
	var paddles_to_clear = []
	for paddle in paddles:
		if paddles[paddle].id == id:
			paddles_to_clear.append(paddle)
	for paddle in paddles_to_clear:
		remove_paddle(paddle)

func update_paddles(new_paddles):
	for paddle in new_paddles:
		var paddle_node = get_node(paddle)
		if DiscordManager.is_lobby_owner():
			paddles[paddle].position = paddle_node.position
			paddles[paddle].rotation = paddle_node.rotation
			if Game.user_id == new_paddles[paddle].id:
				set_paddle_inputs(paddle, get_paddle_inputs(paddle))
		else:
			paddles[paddle].position = new_paddles[paddle].position
			paddles[paddle].rotation = new_paddles[paddle].rotation
			paddle_node.position = new_paddles[paddle].position
			paddle_node.rotation = new_paddles[paddle].rotation
			if Game.user_id == new_paddles[paddle].id:
				var input_data = {
					"paddle": paddle,
					"inputs": get_paddle_inputs(paddle),
				}
				DiscordManager.send_owner(input_data, false)

func get_key(key):
	return int(Input.is_key_pressed(key))

func get_axis(pad, axis):
	return Input.get_joy_axis(pad, axis)

func get_paddle_inputs(paddle):
	var pad = input_list[paddle]
	var inputs = {
		"velocity": Vector2(),
		"rotation": 0.0,
		"dash": false,
	}
	if pad == -1:
		inputs.velocity.x = get_key(KEY_D) - get_key(KEY_A)
		inputs.velocity.y = get_key(KEY_S) - get_key(KEY_W)
		inputs.velocity = inputs.velocity.normalized() * Game.MOVE_SPEED
		inputs.dash = Input.is_key_pressed(KEY_SHIFT)
		inputs.rotation = deg2rad((get_key(KEY_PERIOD) - get_key(KEY_COMMA)) * 4)
	else:
		var left_stick = Vector2(get_axis(pad, JOY_ANALOG_LX), get_axis(pad, JOY_ANALOG_LY))
		var right_stick = Vector2(get_axis(pad, JOY_ANALOG_RX), get_axis(pad, JOY_ANALOG_RY))
		if left_stick.length() > 0.2:
			inputs.velocity = left_stick * Game.MOVE_SPEED
		inputs.dash = Input.is_joy_button_pressed(pad, JOY_L2)
		if right_stick.length() > 0.7:
			var paddle_node = get_node(paddle)
			inputs.rotation = paddle_node.get_angle_to(paddle_node.position + right_stick) * 0.1
	return inputs

func set_paddle_inputs(paddle, inputs):
	if has_node(paddle):
		if get_node(paddle).has_method("set_inputs"):
			get_node(paddle).set_inputs(inputs)

func damage_paddle(paddle):
	paddles[paddle].health -= 1
	if paddles[paddle].health < 1:
		emit_signal("paddle_destroyed", paddles[paddle].name + " was destroyed")
		if DiscordManager.is_lobby_owner():
			var paddle_node = get_node(paddle)
			paddle_node.position = spawns[paddle_node.get_index()].position
			paddle_node.rotation = spawns[paddle_node.get_index()].rotation
		paddles[paddle].health = Game.MAX_HEALTH
	emit_signal("paddle_damaged", paddle, paddles[paddle].health)
	if DiscordManager.is_lobby_owner():
		var paddle_data = {
			"paddle": paddle,
		}
		DiscordManager.send_all(paddle_data, true)

func reset():
	input_list.clear()
	used_inputs.clear()
	for paddle in get_children():
		paddle.queue_free()
	paddles.clear()
