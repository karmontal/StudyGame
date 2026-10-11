extends ToddlerScreen
## Shapes: drag each loose piece into its hole on the wooden board; it snaps in when close.
## Three holes first (circle, square, triangle), later a star and a heart. Between the shape
## boards come little picture puzzles: a drawn picture cut into 2, 3 or 4 pieces that snap
## into the frame. A piece dropped anywhere else floats gently home.

const STAGES := [
	{"kind": "holes", "shapes": ["circle", "square", "triangle"]},
	{"kind": "puzzle", "pieces": 2},
	{"kind": "holes", "shapes": ["circle", "square", "triangle", "star"]},
	{"kind": "puzzle", "pieces": 3},
	{"kind": "holes", "shapes": ["circle", "square", "triangle", "star", "heart"]},
	{"kind": "puzzle", "pieces": 4},
]
const REPEAT_FROM := 2
const SHAPE_COLOURS := {"circle": "red", "square": "blue", "triangle": "yellow", "star": "green", "heart": "pink"}
const PIECE_R := 112.0
const SNAP := 120.0
const FRAME := Rect2(220, 50, 640, 640)  # puzzle frame, board coordinates
const NEXT_DELAY := 3.0

var stage := 0
var puzzles_done := 0
var holes: Array[Dictionary] = []  # {kind, pos}
var pieces: Array[Dictionary] = []  # shapes: {kind, color, pos, home, target, placed}; puzzle: + cell, pic, size, slot
var picture_id := ""
var board: ToddlerBoard
var celebrating := false
var _drag := -1
var _grab := Vector2.ZERO


func setup() -> void:
	bg_color = Color("#E3F2FD")
	board = make_board(_paint)
	board.down.connect(_on_down)
	board.moved.connect(_on_move)
	board.up.connect(_on_up)
	start_stage(0)


func stage_kind() -> String:
	return STAGES[stage].kind


func start_stage(i: int) -> void:
	stage = i
	celebrating = false
	_drag = -1
	holes.clear()
	pieces.clear()
	if stage_kind() == "holes":
		_build_holes(STAGES[i].shapes)
		ToddlerVoice.say("game_shapes")
	else:
		_build_puzzle(int(STAGES[i].pieces))
		ToddlerVoice.say("game_puzzle")


func next_stage() -> void:
	var n := stage + 1
	start_stage(n if n < STAGES.size() else REPEAT_FROM)


func _build_holes(kinds: Array) -> void:
	var n := kinds.size()
	var top_row := mini(n, 3)
	for i in n:
		var row := 0 if i < top_row else 1
		var in_row := top_row if row == 0 else n - top_row
		var col := i if row == 0 else i - top_row
		var x := 540.0 + (col - (in_row - 1) / 2.0) * 300.0
		holes.append({"kind": kinds[i], "pos": Vector2(x, 210 + row * 290)})
	var homes: Array[Vector2] = []
	for k in 6:
		homes.append(Vector2(220 + (k % 3) * 320, 1000 + (k / 3) * 330))
	homes.shuffle()
	var order := kinds.duplicate()
	order.shuffle()
	for i in n:
		var kind: String = order[i]
		var home := homes[i]
		pieces.append({"kind": kind, "color": ToddlerArt.color_by_id(SHAPE_COLOURS[kind]).color,
			"pos": home, "home": home, "target": home, "placed": false})


func board_rect() -> Rect2:
	var rows := 1 if holes.size() <= 3 else 2
	return Rect2(60, 40, 960, 340 + (rows - 1) * 290)


func hole(kind: String) -> Dictionary:
	for h in holes:
		if h.kind == kind:
			return h
	return {}


func _build_puzzle(n: int) -> void:
	picture_id = ToddlerArt.PUZZLES[puzzles_done % ToddlerArt.PUZZLES.size()]
	var pic := ToddlerArt.picture(picture_id)
	var cells: Array[Rect2] = []
	match n:
		2:
			cells = [Rect2(0, 0, 500, 1000), Rect2(500, 0, 500, 1000)]
		3:
			for k in 3:
				cells.append(Rect2(k * 1000.0 / 3.0, 0, 1000.0 / 3.0, 1000))
		_:
			cells = [Rect2(0, 0, 500, 500), Rect2(500, 0, 500, 500), Rect2(0, 500, 500, 500), Rect2(500, 500, 500, 500)]
	var sc := FRAME.size.x / 1000.0
	var homes: Array[Vector2] = []
	for c in cells:
		homes.append(Vector2.ZERO)
	var size0 := cells[0].size * sc
	# Homes below the frame, in the order of a shuffled list.
	var cols := cells.size() if n <= 3 else 2
	var gap := 40.0
	var total_w := cols * size0.x + (cols - 1) * gap
	for k in cells.size():
		var col := k % cols
		var row := k / cols
		homes[k] = Vector2((1080.0 - total_w) / 2.0 + col * (size0.x + gap), 820 + row * (size0.y + gap))
	homes.shuffle()
	for k in cells.size():
		var slot := FRAME.position + cells[k].position * sc
		pieces.append({"kind": "piece", "cell": cells[k], "pic": ToddlerArt.cut(pic, cells[k]), "size": cells[k].size * sc,
			"slot": slot, "pos": homes[k], "home": homes[k], "target": homes[k], "placed": false})


## Centre of piece i (shapes) or its top-left corner (puzzle) as the snap point.
func piece_at(p: Vector2) -> int:
	for i in range(pieces.size() - 1, -1, -1):
		var pc: Dictionary = pieces[i]
		if pc.placed:
			continue
		if pc.kind == "piece":
			if Rect2(pc.pos, pc.size).has_point(p):
				return i
		elif pc.pos.distance_to(p) <= PIECE_R * 1.1:
			return i
	return -1


## Where piece i snaps in (hole centre, or the frame cell's corner).
func snap_point(pc: Dictionary) -> Vector2:
	if pc.kind == "piece":
		return pc.slot
	return hole(pc.kind).pos


func placed_count() -> int:
	return pieces.filter(func(pc): return pc.placed).size()


func _on_down(p: Vector2) -> void:
	_drag = -1 if celebrating else piece_at(p)
	if _drag < 0:
		board.sparkle(p)
		Sfx.play("boing")
		return
	_grab = pieces[_drag].pos - p
	var pc: Dictionary = pieces[_drag]
	pieces.remove_at(_drag)
	pieces.append(pc)
	_drag = pieces.size() - 1
	Sfx.play("boing")


func _on_move(p: Vector2) -> void:
	if _drag >= 0:
		pieces[_drag].pos = p + _grab
		pieces[_drag].target = pieces[_drag].pos


func _on_up(_p: Vector2) -> void:
	if _drag < 0:
		return
	var pc: Dictionary = pieces[_drag]
	_drag = -1
	var goal := snap_point(pc)
	if pc.pos.distance_to(goal) <= SNAP:
		pc.placed = true
		pc.target = goal
		Sfx.play("pop")
		var centre: Vector2 = goal + (pc.size / 2.0 if pc.kind == "piece" else Vector2.ZERO)
		board.sparkle(centre, Color("#FFD54F"), 10)
		if pc.kind != "piece":
			ToddlerVoice.say("s_" + pc.kind)
		if placed_count() == pieces.size():
			_celebrate()
	else:
		pc.target = pc.home
		Sfx.play("whoosh")


func _celebrate() -> void:
	celebrating = true
	board.confetti()
	Sfx.play("cheer")
	if stage_kind() == "puzzle":
		puzzles_done += 1
		ToddlerVoice.say("p_" + picture_id)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_inside_tree():
				ToddlerVoice.say("bravo"))
	else:
		ToddlerVoice.say("bravo")
	var at_stage := stage
	get_tree().create_timer(NEXT_DELAY).timeout.connect(func():
		if is_inside_tree() and celebrating and stage == at_stage:
			next_stage())


func _process(delta: float) -> void:
	super(delta)
	var k := minf(1.0, delta * 7.0)
	for i in pieces.size():
		if i != _drag:
			pieces[i].pos = pieces[i].pos.lerp(pieces[i].target, k)


func _paint(ci: CanvasItem) -> void:
	if stage_kind() == "holes":
		var wood := StyleBoxFlat.new()
		wood.bg_color = Color("#D7A86E")
		wood.set_corner_radius_all(50)
		wood.border_color = Color("#A1764A")
		wood.set_border_width_all(14)
		ci.draw_style_box(wood, board_rect())
		for h in holes:
			ci.draw_colored_polygon(ToddlerArt.shape(h.kind, h.pos, PIECE_R * 1.06), Color("#5D4037"))
			ci.draw_colored_polygon(ToddlerArt.shape(h.kind, h.pos + Vector2(0, 8), PIECE_R * 0.98), Color("#4E342E"))
		for pc in pieces:
			ToddlerArt.draw_shape(ci, pc.kind, pc.pos, PIECE_R, pc.color, 8.0)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(16)
	box.border_color = Color("#A1764A")
	box.set_border_width_all(16)
	box.expand_margin_left = 16
	box.expand_margin_right = 16
	box.expand_margin_top = 16
	box.expand_margin_bottom = 16
	ci.draw_style_box(box, FRAME)
	var sc := FRAME.size.x / 1000.0
	ToddlerArt.draw_picture(ci, ToddlerArt.picture(picture_id), [], Transform2D(0, Vector2(sc, sc), 0, FRAME.position), 7.0, 0.22)
	for pc in pieces:
		var r := Rect2(pc.slot, pc.size)
		ci.draw_rect(r, Color("#B0BEC5"), false, 4.0)
	for pc in pieces:
		var r := Rect2(pc.pos, pc.size)
		if not pc.placed:
			ci.draw_rect(Rect2(r.position + Vector2(0, 10), r.size), Color(0, 0, 0, 0.12))
		ci.draw_rect(r, Color.WHITE)
		var cell: Rect2 = pc.cell
		ToddlerArt.draw_picture(ci, pc.pic, [], Transform2D(0, Vector2(sc, sc), 0, pc.pos - cell.position * sc), 7.0)
		if not pc.placed:
			ci.draw_rect(r, Color("#5C6BC0"), false, 8.0)
