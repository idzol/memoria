extends Control

@export var outline_color: Color = Color(0, 0, 0, 1)
@export var line_width: float = 3.0
@export var dash_length: float = 10.0
@export var dash_gap: float = 7.0
@export var corner_radius: float = 10.0

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_draw_dashed_segment(Vector2(corner_radius, 0), Vector2(rect.size.x - corner_radius, 0))
	_draw_dashed_segment(Vector2(rect.size.x, corner_radius), Vector2(rect.size.x, rect.size.y - corner_radius))
	_draw_dashed_segment(Vector2(rect.size.x - corner_radius, rect.size.y), Vector2(corner_radius, rect.size.y))
	_draw_dashed_segment(Vector2(0, rect.size.y - corner_radius), Vector2(0, corner_radius))

func _draw_dashed_segment(from: Vector2, to: Vector2):
	var distance = from.distance_to(to)
	if distance <= 0.0:
		return
	var direction = (to - from).normalized()
	var offset = 0.0
	while offset < distance:
		var segment_start = from + direction * offset
		var segment_end = from + direction * min(offset + dash_length, distance)
		draw_line(segment_start, segment_end, outline_color, line_width)
		offset += dash_length + dash_gap
