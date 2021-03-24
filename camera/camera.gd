extends Camera2D

const DEFAULT_ZOOM = Vector2(1, 1)

var spawn = Vector2()

func move_and_zoom(paddles):
	var new_zoom = DEFAULT_ZOOM
	if paddles.size() > 0:
		var average = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for paddle in paddles:
			average += paddle.position
			max_x = max(paddle.position.x, max_x)
			min_x = min(paddle.position.x, min_x)
			max_y = max(paddle.position.y, max_y)
			min_y = min(paddle.position.y, min_y)
		average /= paddles.size()
		var x_between_paddles = max(max_x - average.x, average.x - min_x)
		var y_between_paddles = max(max_y - average.y, average.y - min_y)
		var margin_x = OS.window_size.x * 2 / 3
		var margin_y = OS.window_size.y * 2 / 3
		new_zoom = Vector2(
			(2 * x_between_paddles + margin_x) / OS.window_size.x,
			(2 * y_between_paddles + margin_y) / OS.window_size.y
		)
		var largest_zoom = max(new_zoom.x, new_zoom.y)
		new_zoom = Vector2(largest_zoom, largest_zoom)
		if new_zoom < DEFAULT_ZOOM:
			new_zoom = DEFAULT_ZOOM
		position = average
	zoom = zoom.linear_interpolate(new_zoom, 0.05)

func reset():
	position = spawn
