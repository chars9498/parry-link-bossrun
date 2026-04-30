extends Node2D

@export var room_size: Vector2 = Vector2(1280, 960)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(-320, -240), room_size)
	var base_colors: Array[Color] = [
		Color(0.08, 0.10, 0.16), Color(0.10, 0.11, 0.18), Color(0.12, 0.13, 0.20),
		Color(0.14, 0.12, 0.18), Color(0.11, 0.10, 0.15)
	]
	draw_rect(rect, base_colors[0], true)

	for x in range(int(rect.position.x), int(rect.end.x), 16):
		for y in range(int(rect.position.y), int(rect.end.y), 16):
			var hash: int = abs((x * 92821 + y * 68917) % 7919)
			var idx: int = hash % base_colors.size()
			var c: Color = base_colors[idx]
			draw_rect(Rect2(Vector2(x, y), Vector2(16, 16)), c, true)
			if hash % 11 == 0:
				draw_circle(Vector2(x + 8, y + 8), 2.0 + float(hash % 3), Color(0.18, 0.18, 0.22, 0.55))
			if hash % 17 == 0:
				draw_line(Vector2(x + 2, y + 3), Vector2(x + 12, y + 10), Color(0.07, 0.07, 0.1, 0.6), 1.0)
			if hash % 23 == 0:
				draw_circle(Vector2(x + 7, y + 9), 3.0, Color(0.14, 0.35, 0.22, 0.45)) # moss
			if hash % 29 == 0:
				draw_circle(Vector2(x + 8, y + 8), 4.0, Color(0.16, 0.46, 0.36, 0.3)) # slime stain

	# outer walls / rock border
	for i in range(0, 52, 6):
		var shade: Color = Color(0.03 + 0.001 * i, 0.04 + 0.001 * i, 0.07 + 0.001 * i, 1)
		draw_rect(Rect2(rect.position + Vector2(i, i), Vector2(rect.size.x - i * 2, 3)), shade, true)
		draw_rect(Rect2(rect.position + Vector2(i, rect.size.y - i - 3), Vector2(rect.size.x - i * 2, 3)), shade, true)
		draw_rect(Rect2(rect.position + Vector2(i, i), Vector2(3, rect.size.y - i * 2)), shade, true)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - i - 3, i), Vector2(3, rect.size.y - i * 2)), shade, true)

	# old stone glyphs near edge
	for center in [Vector2(120, 60), Vector2(890, 70), Vector2(70, 540), Vector2(930, 530)]:
		draw_arc(center, 18, 0, TAU, 24, Color(0.24, 0.26, 0.33, 0.6), 2.0)
		draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), Color(0.24, 0.26, 0.33, 0.55), 2.0)

	# vignette
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 90)), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 90), Vector2(rect.size.x, 90)), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(rect.position, Vector2(90, rect.size.y)), Color(0, 0, 0, 0.28), true)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 90, 0), Vector2(90, rect.size.y)), Color(0, 0, 0, 0.28), true)
