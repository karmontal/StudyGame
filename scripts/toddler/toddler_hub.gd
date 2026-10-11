extends ToddlerScreen
## Aya's games (age 2): five big picture buttons, nothing to read. Leaving needs a parent's long press.

const GAMES := [
	{"id": "color", "screen": "toddler_color", "bg": "#FFCDD2"},
	{"id": "sort", "screen": "toddler_sort", "bg": "#C8E6C9"},
	{"id": "shapes", "screen": "toddler_shapes", "bg": "#BBDEFB"},
	{"id": "animals", "screen": "toddler_animals", "bg": "#FFE0B2"},
	{"id": "balloons", "screen": "toddler_balloons", "bg": "#E1BEE7"},
]


func setup() -> void:
	var title := UI.label("ألعاب آية", 34, UI.MUTED)
	title.name = "Title"
	title.position = Vector2(40, 60)
	title.size = Vector2(600, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var w := 470.0
	var h := 480.0
	var spots := [Vector2(50, 220), Vector2(560, 220), Vector2(50, 740), Vector2(560, 740), Vector2(50, 1260)]
	for i in GAMES.size():
		var g: Dictionary = GAMES[i]
		var size_ := Vector2(980 if i == 4 else w, h)
		var b := ToddlerButton.make("Game_" + g.id, size_, Color(g.bg), Callable(self, "_paint_" + g.id))
		b.position = spots[i]
		var target: String = g.screen
		b.pressed.connect(func(): _go(target))
		add_child(b)
	ToddlerVoice.say("hello")


func leave() -> void:
	_go("profiles")


func go_back() -> void:
	pass


static func _paint_color(ci: CanvasItem, r: Rect2) -> void:
	var pic := ToddlerArt.picture("flower")
	ToddlerArt.draw_picture(ci, pic, [], ToddlerArt.fit(Rect2(r.position, r.size * Vector2(0.85, 1.0))), 7.0)
	# A paint brush leaning on the flower.
	var base := r.position + r.size * Vector2(0.78, 0.92)
	var tip := r.position + r.size * Vector2(0.95, 0.42)
	ci.draw_line(base, tip, Color("#8D6E63"), 26.0, true)
	ci.draw_line(base.lerp(tip, 0.72), tip, Color("#B0BEC5"), 30.0, true)
	var dir := (tip - base).normalized()
	var side := dir.orthogonal() * 22.0
	ci.draw_colored_polygon(PackedVector2Array([tip + side, tip - side, tip + dir * 70.0]), Color("#E53935"))


static func _paint_sort(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	for i in 3:
		var col: Color = ToddlerArt.COLORS[[0, 2, 1][i]].color
		ToddlerArt.draw_ball(ci, c + Vector2(-110 + i * 110, -70 - (30 if i == 1 else 0)), 62, col)
	_basket(ci, Rect2(c + Vector2(-190, -20), Vector2(380, 210)), Color("#C68B59"))


static func _basket(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var inset := r.size.x * 0.1
	var body := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0),
		r.end - Vector2(inset, 0), Vector2(r.position.x + inset, r.end.y)])
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, ToddlerArt.OUTLINE, 14.0, true)
	ci.draw_colored_polygon(body, col)
	for k in range(1, 4):
		var y := r.position.y + r.size.y * k / 4.0
		var dx := inset * k / 4.0
		ci.draw_line(Vector2(r.position.x + dx + 6, y), Vector2(r.end.x - dx - 6, y), col.darkened(0.3), 6.0, true)
	ci.draw_line(r.position, r.position + Vector2(r.size.x, 0), col.darkened(0.4), 18.0, true)


static func _paint_shapes(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var d := minf(r.size.x, r.size.y) * 0.24
	ToddlerArt.draw_shape(ci, "circle", c + Vector2(-d, -d), d * 0.8, ToddlerArt.COLORS[0].color, 6.0)
	ToddlerArt.draw_shape(ci, "square", c + Vector2(d, -d), d * 0.8, ToddlerArt.COLORS[2].color, 6.0)
	ToddlerArt.draw_shape(ci, "triangle", c + Vector2(-d, d), d * 0.85, ToddlerArt.COLORS[1].color, 6.0)
	ToddlerArt.draw_shape(ci, "star", c + Vector2(d, d), d * 0.85, ToddlerArt.COLORS[3].color, 6.0)


static func _paint_animals(ci: CanvasItem, r: Rect2) -> void:
	ToddlerArt.draw_picture(ci, ToddlerArt.picture("cow"), [], ToddlerArt.fit(r), 7.0)


static func _paint_balloons(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var cols := [0, 2, 1, 3, 5]
	for i in 5:
		var x := c.x + (i - 2) * 175.0
		var y := c.y - 70.0 + (40.0 if i % 2 == 1 else -20.0)
		ToddlerArt.draw_balloon(ci, Vector2(x, y), 78.0, ToddlerArt.COLORS[cols[i]].color, i)
