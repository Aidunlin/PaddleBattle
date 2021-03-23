extends Camera2D

const DEFAULT_ZOOM = Vector2(1, 1)

func modify(paddles):
	var new_zoom = DEFAULT_ZOOM
	if paddles.size() > 0:
		var avg = Vector2()
		var max_x = -INF
		var min_x = INF
		var max_y = -INF
		var min_y = INF
		for paddle in paddles:
			avg += paddle.position
			max_x = max(paddle.position.x, max_x)
			min_x = min(paddle.position.x, min_x)
			max_y = max(paddle.position.y, max_y)
			min_y = min(paddle.position.y, min_y)
		avg /= paddles.size()
		new_zoom = Vector2(
			(2 * max(max_x - avg.x, avg.x - min_x) + OS.window_size.x / 1.5) / OS.window_size.x,
			(2 * max(max_y - avg.y, avg.y - min_y) + OS.window_size.y / 1.5) / OS.window_size.y
		)
		new_zoom = Vector2(max(new_zoom.x, new_zoom.y), max(new_zoom.x, new_zoom.y))
		if new_zoom < DEFAULT_ZOOM:
			new_zoom = DEFAULT_ZOOM
		position = avg
	zoom = zoom.linear_interpolate(new_zoom, 0.05)
