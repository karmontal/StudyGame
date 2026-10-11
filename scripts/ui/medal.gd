class_name Medal
extends Control
## A badge drawn in code: two ribbons and a colored disc with a star. Grey when not earned yet.

var color := Color.GOLD
var earned := true


static func make(color_: Color, earned_: bool, size_: float = 150.0) -> Medal:
	var m := Medal.new()
	m.color = color_
	m.earned = earned_
	m.custom_minimum_size = Vector2(size_, size_)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var col := color if earned else Color("#C9C4B8")
	var ribbon := col.darkened(0.25)
	draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.28, 0), o + Vector2(s * 0.46, 0),
		o + Vector2(s * 0.56, s * 0.42), o + Vector2(s * 0.38, s * 0.42)]), ribbon)
	draw_colored_polygon(PackedVector2Array([o + Vector2(s * 0.54, 0), o + Vector2(s * 0.72, 0),
		o + Vector2(s * 0.62, s * 0.42), o + Vector2(s * 0.44, s * 0.42)]), ribbon.lightened(0.15))
	var c := o + Vector2(s * 0.5, s * 0.64)
	var r := s * 0.34
	draw_circle(c + Vector2(0, r * 0.07), r, col.darkened(0.3))
	draw_circle(c, r, col)
	draw_circle(c, r * 0.76, col.lightened(0.25))
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * r * (0.55 if i % 2 == 0 else 0.23))
	draw_colored_polygon(pts, Color.WHITE if earned else Color("#E8E4DA"))
