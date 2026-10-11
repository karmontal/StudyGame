extends ToddlerScreen
## Colour sorting: drag each ball into the basket of its colour. Two baskets at first, then three,
## then four. A wrong basket just lets the ball float gently home (no error sound). Every ball in
## place cheers and says its colour; a full round ends with confetti and "برافو آية!".

const COLOURS := ["red", "yellow", "blue", "green", "orange", "pink"]
const BALL_R := 100.0
const BALLS_PER_BASKET := 2
const NEXT_ROUND_DELAY := 3.0

var round_number := 0
var baskets: Array[Dictionary] = []  # {color_id, color, rect, count}
var balls: Array[Dictionary] = []  # {color_id, color, pos, home, target, placed, basket}
var board: ToddlerBoard
var celebrating := false
var _drag := -1
var _grab := Vector2.ZERO
var _down_at := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	bg_color = Color("#E8F5E9")
	board = make_board(_paint)
	board.down.connect(_on_down)
	board.moved.connect(_on_move)
	board.up.connect(_on_up)
	new_round()
	ToddlerVoice.say("game_sort")


static func basket_count(round_: int) -> int:
	return 2 if round_ < 2 else (3 if round_ < 4 else 4)


func new_round() -> void:
	celebrating = false
	_drag = -1
	var n := basket_count(round_number)
	var ids := COLOURS.duplicate()
	ids.shuffle()
	ids = ids.slice(0, n)
	baskets.clear()
	var gap := 40.0
	var w := (1080.0 - gap * (n + 1)) / n
	var h := 330.0
	for i in n:
		var c := ToddlerArt.color_by_id(ids[i])
		baskets.append({"color_id": c.id, "color": c.color, "rect": Rect2(gap + i * (w + gap), 1230, w, h), "count": 0})
	# Balls on a shuffled grid of slots in the top part of the board.
	var slots: Array[Vector2] = []
	for row in 3:
		for col in 4:
			slots.append(Vector2(150 + col * 260 + (60 if row % 2 == 1 else 0) - 30, 170 + row * 270))
	slots.shuffle()
	balls.clear()
	for i in n * BALLS_PER_BASKET:
		var c := ToddlerArt.color_by_id(ids[i % n])
		var home := slots[i] + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20))
		balls.append({"color_id": c.id, "color": c.color, "pos": home, "home": home, "target": home, "placed": false, "basket": -1})


func ball_at(p: Vector2) -> int:
	for i in range(balls.size() - 1, -1, -1):
		if not balls[i].placed and balls[i].pos.distance_to(p) <= BALL_R * 1.15:
			return i
	return -1


func basket_at(p: Vector2) -> int:
	for i in baskets.size():
		var r: Rect2 = baskets[i].rect
		if Rect2(r.position - Vector2(30, 160), r.size + Vector2(60, 190)).has_point(p):
			return i
	return -1


func basket_index(color_id: String) -> int:
	for i in baskets.size():
		if baskets[i].color_id == color_id:
			return i
	return -1


func placed_count() -> int:
	return balls.filter(func(b): return b.placed).size()


func _on_down(p: Vector2) -> void:
	if celebrating:
		board.sparkle(p)
		return
	_drag = ball_at(p)
	_down_at = p
	if _drag < 0:
		board.sparkle(p)
		Sfx.play("boing")
		return
	_grab = balls[_drag].pos - p
	# Draw the dragged ball on top.
	var b: Dictionary = balls[_drag]
	balls.remove_at(_drag)
	balls.append(b)
	_drag = balls.size() - 1


func _on_move(p: Vector2) -> void:
	if _drag >= 0:
		balls[_drag].pos = p + _grab
		balls[_drag].target = balls[_drag].pos


func _on_up(p: Vector2) -> void:
	if _drag < 0:
		return
	var ball: Dictionary = balls[_drag]
	_drag = -1
	if p.distance_to(_down_at) < 20.0:
		# Just a tap: the ball says its colour.
		ball.target = ball.home
		Sfx.play("boing")
		ToddlerVoice.say(ToddlerVoice.colour_key(ball.color_id))
		board.sparkle(ball.pos, ball.color.lightened(0.3))
		return
	var bi := basket_at(ball.pos)
	if bi >= 0 and baskets[bi].color_id == ball.color_id:
		_place(ball, bi)
	else:
		ball.target = ball.home  # floats back gently, no error sound
		if bi >= 0:
			Sfx.play("whoosh")


func _place(ball: Dictionary, bi: int) -> void:
	var basket: Dictionary = baskets[bi]
	var r: Rect2 = basket.rect
	var k: int = basket.count
	basket.count = k + 1
	var spread := minf(r.size.x * 0.25, BALL_R * 0.9)
	ball.placed = true
	ball.basket = bi
	ball.target = Vector2(r.get_center().x + (k - 0.5) * spread * 1.2, r.position.y + 20 - k * 12)
	Sfx.play("correct")
	ToddlerVoice.say(ToddlerVoice.colour_key(ball.color_id))
	board.sparkle(ball.target, ball.color.lightened(0.3), 10)
	if placed_count() == balls.size():
		_celebrate()


func _celebrate() -> void:
	celebrating = true
	board.confetti()
	Sfx.play("cheer")
	ToddlerVoice.say("bravo")
	round_number += 1
	var done_round := round_number
	get_tree().create_timer(NEXT_ROUND_DELAY).timeout.connect(func():
		if is_inside_tree() and celebrating and round_number == done_round:
			new_round())


func _process(delta: float) -> void:
	super(delta)
	var k := minf(1.0, delta * 7.0)
	for i in balls.size():
		if i != _drag:
			balls[i].pos = balls[i].pos.lerp(balls[i].target, k)


func _paint(ci: CanvasItem) -> void:
	# Back of each basket, the balls inside it, then the front so they sit in the basket.
	for b in baskets:
		var r: Rect2 = b.rect
		ci.draw_colored_polygon(ToddlerArt.ellipse(Vector2(r.get_center().x, r.position.y), r.size.x / 2.0, 34), Color(b.color).darkened(0.5))
	for ball in balls:
		if ball.placed:
			ToddlerArt.draw_ball(ci, ball.pos, BALL_R * 0.8, ball.color)
	for b in baskets:
		_draw_basket(ci, b.rect, b.color)
	for ball in balls:
		if not ball.placed:
			ToddlerArt.draw_ball(ci, ball.pos, BALL_R, ball.color)


static func _draw_basket(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var inset := r.size.x * 0.12
	var body := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0),
		r.end - Vector2(inset, 0), Vector2(r.position.x + inset, r.end.y)])
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, ToddlerArt.OUTLINE, 16.0, true)
	ci.draw_colored_polygon(body, col.lightened(0.1))
	for k in range(1, 5):
		var y := r.position.y + r.size.y * k / 5.0
		var dx := inset * k / 5.0
		ci.draw_line(Vector2(r.position.x + dx + 8, y), Vector2(r.end.x - dx - 8, y), col.darkened(0.25), 7.0, true)
	for k in range(1, 6):
		var x := r.position.x + r.size.x * k / 6.0
		ci.draw_line(Vector2(x, r.position.y + 10), Vector2(lerpf(x, r.get_center().x, 0.12), r.end.y - 6), col.darkened(0.25), 5.0, true)
	ci.draw_line(r.position + Vector2(-8, 0), r.position + Vector2(r.size.x + 8, 0), col.darkened(0.4), 26.0, true)
