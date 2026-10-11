class_name Backdrop
extends Control
## A soft, playful page background: a color wash at the top and a few pale bubbles. Drawn in code and
## placed behind a screen's content (first child), so it never takes taps.

var color := Color("#F7B500")
var wash_height := 520.0


static func make(color_: Color, wash_height_: float = 520.0) -> Backdrop:
	var b := Backdrop.new()
	b.color = color_
	b.wash_height = wash_height_
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


func _draw() -> void:
	var w := size.x
	# Color wash with a wavy bottom edge.
	var top := PackedVector2Array([Vector2(0, 0), Vector2(w, 0)])
	var steps := 24
	for i in steps + 1:
		var x := w - w * i / float(steps)
		top.append(Vector2(x, wash_height + sin(i / float(steps) * TAU * 1.5) * 26.0))
	draw_colored_polygon(top, color.lerp(Color.WHITE, 0.72))
	# Bubbles in fixed spots (same picture every time), in the kid's color and the sunny yellow.
	var bubbles := [[0.08, 0.10, 90.0], [0.86, 0.05, 130.0], [0.7, 0.2, 46.0], [0.2, 0.28, 34.0],
		[0.94, 0.45, 70.0], [0.04, 0.62, 110.0], [0.9, 0.82, 120.0], [0.15, 0.93, 60.0]]
	for i in bubbles.size():
		var bb: Array = bubbles[i]
		var c := Vector2(w * bb[0], size.y * bb[1])
		var r: float = bb[2]
		var tint := color if i % 2 == 0 else UI.STAR
		draw_circle(c, r, Color(tint, 0.10))
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.35))
