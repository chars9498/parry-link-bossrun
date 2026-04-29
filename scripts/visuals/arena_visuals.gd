extends Node2D

@export var room_size: Vector2 = Vector2(1280, 960)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(-320, -240), room_size)
	draw_rect(rect, Color(0.09, 0.11, 0.16), true)
	for x in range(int(rect.position.x), int(rect.end.x), 24):
		for y in range(int(rect.position.y), int(rect.end.y), 24):
			var n := float(((x * 13 + y * 7) % 23)) / 23.0
			var c := Color(0.13 + 0.09 * n, 0.12 + 0.06 * n, 0.16 + 0.07 * n)
			draw_rect(Rect2(Vector2(x, y), Vector2(22, 22)), c, true)
	# dark wall border
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 42)), Color(0.04, 0.05, 0.08), true)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 42), Vector2(rect.size.x, 42)), Color(0.04, 0.05, 0.08), true)
	draw_rect(Rect2(rect.position, Vector2(42, rect.size.y)), Color(0.04, 0.05, 0.08), true)
	draw_rect(Rect2(Vector2(rect.end.x - 42, rect.position.y), Vector2(42, rect.size.y)), Color(0.04, 0.05, 0.08), true)
