extends ToddlerScreen
## Tap-to-fill colouring: pick a colour from the six big circles, tap a part of the picture to
## fill it. A tap with no new pick keeps the last colour. The brush button switches to free
## drawing, where the finger paints thick strokes. The arrows change picture (or, while drawing,
## start a clean page). Each picture keeps its colours while the screen is open.

const PALETTE := ["red", "yellow", "blue", "green", "orange", "pink"]
const CANVAS := Rect2(90, 190, 900, 900)  # screen coordinates
const STROKE := 44.0
const MAX_POINTS := 5000

var pic_index := 0
var color_id := "red"
var drawing := false
var fills := {}  # picture id -> Array[Color]
var strokes: Array[Dictionary] = []  # {color, points}
var canvas: ToddlerBoard
var _palette: Array[ToddlerButton] = []
var _mode_button: ToddlerButton


func setup() -> void:
	bg_color = Color("#FFF3E0")
	canvas = ToddlerBoard.new()
	canvas.name = "Canvas"
	canvas.position = CANVAS.position
	canvas.size = CANVAS.size
	canvas.painter = _paint_canvas
	canvas.down.connect(_on_down)
	canvas.moved.connect(_on_move)
	canvas.up.connect(func(_p): pass)
	add_child(canvas)
	var prev := ToddlerButton.make("Prev", Vector2(200, 200), Color("#FFFFFF"), func(ci, r): _arrow(ci, r, -1), true)
	prev.position = Vector2(90, 1120)
	prev.pressed.connect(func(): change_picture(-1))
	add_child(prev)
	_mode_button = ToddlerButton.make("Mode", Vector2(200, 200), Color("#FFFFFF"), _paint_mode, true)
	_mode_button.position = Vector2(440, 1120)
	_mode_button.pressed.connect(func(): set_drawing(not drawing))
	add_child(_mode_button)
	var next := ToddlerButton.make("Next", Vector2(200, 200), Color("#FFFFFF"), func(ci, r): _arrow(ci, r, 1), true)
	next.position = Vector2(790, 1120)
	next.pressed.connect(func(): change_picture(1))
	add_child(next)
	for i in PALETTE.size():
		var c := ToddlerArt.color_by_id(PALETTE[i])
		var b := ToddlerButton.make("Color_" + c.id, Vector2(210, 210), c.color, Callable(), true)
		b.position = Vector2(150 + (i % 3) * 290, 1375 + (i / 3) * 255)
		var id: String = c.id
		b.pressed.connect(func(): pick(id))
		add_child(b)
		_palette.append(b)
	_mark_palette()
	ToddlerVoice.say("game_color")


func picture_id() -> String:
	return ToddlerArt.COLORING[pic_index]


func picture() -> Dictionary:
	return ToddlerArt.picture(picture_id())


## The current picture's fill colours (white until painted).
func current_fills() -> Array:
	var id := picture_id()
	if not fills.has(id):
		var arr := []
		for i in picture().regions.size():
			arr.append(Color.WHITE)
		fills[id] = arr
	return fills[id]


func pick(id: String) -> void:
	color_id = id
	_mark_palette()
	ToddlerVoice.say(ToddlerVoice.colour_key(id))


func change_picture(step: int) -> void:
	Sfx.play("whoosh")
	if drawing:
		strokes.clear()
		return
	pic_index = posmod(pic_index + step, ToddlerArt.COLORING.size())
	ToddlerVoice.say("p_" + picture_id())


func set_drawing(on: bool) -> void:
	drawing = on
	_mode_button.queue_redraw()
	ToddlerVoice.say("game_draw" if on else "game_color")


## Canvas transform: picture box -> canvas coordinates.
func _xf() -> Transform2D:
	return ToddlerArt.fit(Rect2(Vector2.ZERO, CANVAS.size).grow(-30))


## Canvas point (local) inside region i of the current picture.
func region_point(i: int) -> Vector2:
	return _xf() * ToddlerArt.region_point(picture(), i)


func _on_down(p: Vector2) -> void:
	var col: Color = ToddlerArt.color_by_id(color_id).color
	if drawing:
		strokes.append({"color": col, "points": PackedVector2Array([p])})
		_trim()
		return
	var region := ToddlerArt.region_at(picture(), _xf().affine_inverse() * p)
	if region >= 0:
		current_fills()[region] = col
		Sfx.play("pop")
	else:
		Sfx.play("boing")
	canvas.sparkle(p, col.lightened(0.2))


func _on_move(p: Vector2) -> void:
	if not drawing or strokes.is_empty():
		return
	var pts: PackedVector2Array = strokes[-1].points
	if pts[-1].distance_to(p) >= 8.0:
		pts.append(Vector2(clampf(p.x, 0, CANVAS.size.x), clampf(p.y, 0, CANVAS.size.y)))
		strokes[-1].points = pts
		_trim()


func _trim() -> void:
	var total := 0
	for s in strokes:
		total += s.points.size()
	while total > MAX_POINTS and strokes.size() > 1:
		total -= strokes[0].points.size()
		strokes.remove_at(0)


func _mark_palette() -> void:
	for b in _palette:
		b.selected = b.name == "Color_" + color_id


func _paint_canvas(ci: CanvasItem) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(40)
	box.shadow_color = Color(0, 0, 0, 0.1)
	box.shadow_size = 10
	ci.draw_style_box(box, Rect2(Vector2.ZERO, CANVAS.size))
	if drawing:
		for s in strokes:
			var pts: PackedVector2Array = s.points
			for p in pts:
				ci.draw_circle(p, STROKE / 2.0, s.color)
			if pts.size() > 1:
				ci.draw_polyline(pts, s.color, STROKE, true)
		return
	ToddlerArt.draw_picture(ci, picture(), current_fills(), _xf(), 9.0)


func _paint_mode(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	if drawing:
		# Back to the pictures: a tiny sun.
		ToddlerArt.draw_picture(ci, ToddlerArt.picture("sun"), [], ToddlerArt.fit(r.grow(-6)), 4.0)
		return
	var base := c + Vector2(-50, 55)
	var tip := c + Vector2(40, -45)
	ci.draw_line(base, tip, Color("#8D6E63"), 22.0, true)
	ci.draw_line(base.lerp(tip, 0.7), tip, Color("#B0BEC5"), 26.0, true)
	var dir := (tip - base).normalized()
	ci.draw_colored_polygon(PackedVector2Array([tip + dir.orthogonal() * 20, tip - dir.orthogonal() * 20, tip + dir * 55]),
		ToddlerArt.color_by_id(color_id).color)


static func _arrow(ci: CanvasItem, r: Rect2, dir: int) -> void:
	var c := r.get_center()
	var s := r.size.x * 0.32
	var pts := PackedVector2Array([c + Vector2(s * dir, 0), c + Vector2(-s * 0.4 * dir, -s), c + Vector2(-s * 0.4 * dir, s)])
	ci.draw_colored_polygon(pts, Color("#5C6BC0"))
