class_name ToddlerHold
extends ToddlerBoard
## A parents' button that only fires after being held for HOLD_SECONDS, so a toddler's quick taps
## never leave the game. A ring fills up while it is held.

signal held

const HOLD_SECONDS := 1.5

var icon := "back"  # back, play
var color := Color("#90A4AE")
var progress := 0.0


static func make(icon_: String, diameter: float = 150.0, color_: Color = Color("#90A4AE")) -> ToddlerHold:
	var h := ToddlerHold.new()
	h.icon = icon_
	h.color = color_
	h.custom_minimum_size = Vector2(diameter, diameter)
	h.size = Vector2(diameter, diameter)
	h.down.connect(func(_p): h.progress = 0.0001)
	h.up.connect(func(_p): h.progress = 0.0)
	return h


func _process(delta: float) -> void:
	if progress > 0.0 and is_held():
		progress += delta
		if progress >= HOLD_SECONDS:
			progress = 0.0
			_pointer = NONE
			held.emit()
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c, r, color)
	var s := r * 0.42
	var w := maxf(6.0, r * 0.12)
	if icon == "play":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s, 0), c + Vector2(-s * 0.6, s)]), Color.WHITE)
	else:
		# An arrow pointing right (back in an Arabic layout).
		draw_line(c + Vector2(-s, 0), c + Vector2(s * 0.9, 0), Color.WHITE, w, true)
		draw_polyline(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.8), c + Vector2(s, 0), c + Vector2(s * 0.1, s * 0.8)]), Color.WHITE, w, true)
	if progress > 0.0:
		draw_arc(c, r - w * 0.6, -PI / 2.0, -PI / 2.0 + TAU * progress / HOLD_SECONDS, 48, Color("#FFD54F"), w * 1.2, true)
