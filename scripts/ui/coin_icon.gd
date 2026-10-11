class_name CoinIcon
extends Control
## A gold coin drawn in code (the Cairo font has no coin or emoji glyphs).


static func make(diameter: float = 56.0) -> CoinIcon:
	var c := CoinIcon.new()
	c.custom_minimum_size = Vector2(diameter, diameter)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A coin followed by a number, e.g. for the coin balance.
static func with_amount(amount: int, font_size: int = 40, color: Color = UI.TEXT) -> HBoxContainer:
	var h := UI.hbox(10)
	h.add_child(make(font_size * 1.2))
	var l := UI.label(str(amount), font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.name = "Amount"
	h.add_child(l)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c + Vector2(0, r * 0.08), r, Color("#C98A00"))
	draw_circle(c, r, Color("#F7B500"))
	draw_circle(c, r * 0.72, Color("#FFD24D"))
	draw_arc(c, r * 0.72, 0, TAU, 32, Color("#E0A200"), maxf(2.0, r * 0.08))
	# A small star in the middle.
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r * (0.42 if i % 2 == 0 else 0.18)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color("#E0A200"))
