class_name StarRow
extends Control
## Draws a row of stars (filled up to `filled`). The font has no star glyph, so they are polygons.

var filled := 0:
	set(v):
		filled = v
		queue_redraw()
var total := 3
var star_size := 40.0


static func make(filled_: int, size_: float = 40.0, total_: int = 3) -> StarRow:
	var s := StarRow.new()
	s.filled = filled_
	s.total = total_
	s.star_size = size_
	s.custom_minimum_size = Vector2(size_ * total_ * 1.15, size_)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var step := star_size * 1.15
	var start_x := (size.x - step * total) / 2.0 + step / 2.0
	for i in total:
		# Fill from the reading side: the first star is the right-most in RTL layouts.
		var slot := total - 1 - i if is_layout_rtl() else i
		var c := Vector2(start_x + slot * step, size.y / 2.0)
		draw_colored_polygon(_points(c, star_size / 2.0), UI.STAR if i < filled else UI.STAR_OFF)


static func _points(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var radius := r if k % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
