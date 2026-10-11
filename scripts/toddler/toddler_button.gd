class_name ToddlerButton
extends Button
## A big picture button: a rounded card (or a circle) with a drawing from `painter`, and a little
## bounce when tapped. No text, so a toddler doesn't need to read.

var painter: Callable  # func(ci: CanvasItem, area: Rect2) -> void
var bg := Color.WHITE
var round_shape := false
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var _bounce := 0.0


static func make(name_: String, size_: Vector2, bg_: Color, painter_: Callable, round_ := false) -> ToddlerButton:
	var b := ToddlerButton.new()
	b.name = name_
	b.bg = bg_
	b.painter = painter_
	b.round_shape = round_
	b.custom_minimum_size = size_
	b.size = size_
	b.focus_mode = Control.FOCUS_NONE
	for key in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(key, StyleBoxEmpty.new())
	b.button_down.connect(b.bounce)
	return b


func bounce() -> void:
	_bounce = 1.0


func _process(delta: float) -> void:
	if _bounce > 0.0:
		_bounce = maxf(0.0, _bounce - delta * 2.2)
		queue_redraw()


func _draw() -> void:
	var s := 1.0 + 0.12 * sin(_bounce * PI)
	if get_draw_mode() == DRAW_PRESSED:
		s *= 0.94
	draw_set_transform(size * (1.0 - s) / 2.0, 0.0, Vector2(s, s))
	var area := Rect2(Vector2.ZERO, size)
	if round_shape:
		var r := minf(size.x, size.y) / 2.0
		draw_circle(size / 2.0 + Vector2(0, 6), r - 4, Color(0, 0, 0, 0.15))
		if selected:
			draw_circle(size / 2.0, r, ToddlerArt.OUTLINE)
			draw_circle(size / 2.0, r - 9, Color.WHITE)
			draw_circle(size / 2.0, r - 22, bg)
		else:
			draw_circle(size / 2.0, r - 12, bg)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.set_corner_radius_all(48)
		box.shadow_color = Color(0, 0, 0, 0.12)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 8)
		if selected:
			box.border_color = ToddlerArt.OUTLINE
			box.set_border_width_all(8)
		draw_style_box(box, area)
	if painter.is_valid():
		painter.call(self, area.grow(-24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
