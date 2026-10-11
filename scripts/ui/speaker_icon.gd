class_name SpeakerIcon
extends Control
## A loudspeaker drawn in code (the font has no emoji): a box, a cone and sound waves.
## With `muted` the waves become a cross.

var color := Color.WHITE
var muted := false


static func make(color_: Color, size_: float = 64.0, muted_ := false) -> SpeakerIcon:
	var s := SpeakerIcon.new()
	s.color = color_
	s.muted = muted_
	s.custom_minimum_size = Vector2(size_, size_)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var w := maxf(2.0, s * 0.07)
	draw_rect(Rect2(o + Vector2(s * 0.08, s * 0.36), Vector2(s * 0.18, s * 0.28)), color)
	draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.24, s * 0.36), o + Vector2(s * 0.48, s * 0.14),
		o + Vector2(s * 0.48, s * 0.86), o + Vector2(s * 0.24, s * 0.64)]), color)
	var c := o + Vector2(s * 0.5, s * 0.5)
	if muted:
		draw_line(o + Vector2(s * 0.62, s * 0.36), o + Vector2(s * 0.88, s * 0.64), color, w, true)
		draw_line(o + Vector2(s * 0.88, s * 0.36), o + Vector2(s * 0.62, s * 0.64), color, w, true)
		return
	for r in [0.2, 0.34]:
		draw_arc(c, s * r, -PI / 4, PI / 4, 16, color, w, true)
