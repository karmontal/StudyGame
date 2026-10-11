extends ToddlerScreen
## Balloons float up the sky; a tap pops one with a pop sound and says its colour. Balloons that
## reach the top just drift away: nothing is lost. Every ten pops brings confetti.

const BALLOON_R := 110.0
const MAX_BALLOONS := 6
const SPAWN_EVERY := 1.1

var balloons := []  # {color_id, color, x, y, speed, phase}
var popped := 0
var board: ToddlerBoard
var _spawn_timer := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	bg_color = Color("#E1F5FE")
	board = make_board(_paint)
	board.down.connect(_on_down)
	for i in 3:
		spawn(_rng.randi_range(0, ToddlerArt.COLORS.size() - 1), Vector2(_rng.randf_range(160, 920), 500 + i * 420))
	ToddlerVoice.say("game_balloons")


func spawn(color_index: int, at: Vector2) -> Dictionary:
	var c: Dictionary = ToddlerArt.COLORS[color_index]
	var b := {"color_id": c.id, "color": c.color, "x": at.x, "y": at.y,
		"speed": _rng.randf_range(110, 170), "phase": _rng.randf_range(0, TAU)}
	balloons.append(b)
	return b


## Where balloon b is drawn now (it sways a little from side to side).
func balloon_pos(b: Dictionary) -> Vector2:
	return Vector2(b.x + sin(_time * 1.4 + b.phase) * 22.0, b.y)


func balloon_at(p: Vector2) -> int:
	for i in range(balloons.size() - 1, -1, -1):
		var d := (p - balloon_pos(balloons[i])) / Vector2(BALLOON_R * 1.1, BALLOON_R * 1.35)
		if d.length() <= 1.0:
			return i
	return -1


func _on_down(p: Vector2) -> void:
	var i := balloon_at(p)
	if i < 0:
		board.sparkle(p, Color.WHITE, 6)
		return
	var b: Dictionary = balloons[i]
	balloons.remove_at(i)
	popped += 1
	board.sparkle(balloon_pos(b), b.color, 12)
	board.sparkle(balloon_pos(b), Color("#FFD54F"), 6)
	Sfx.play("pop")
	ToddlerVoice.say(ToddlerVoice.colour_key(b.color_id))
	if popped % 10 == 0:
		board.confetti()
		Sfx.play("cheer")
		ToddlerVoice.say("bravo")


func _process(delta: float) -> void:
	super(delta)
	_time += delta
	for b in balloons:
		b.y -= b.speed * delta
	balloons = balloons.filter(func(b): return b.y > -BALLOON_R * 3.0)
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_EVERY and balloons.size() < MAX_BALLOONS:
		_spawn_timer = 0.0
		spawn(_rng.randi_range(0, ToddlerArt.COLORS.size() - 1), Vector2(_rng.randf_range(150, 930), board.size.y + BALLOON_R * 1.3))


func _paint(ci: CanvasItem) -> void:
	# Soft clouds in the sky.
	for c in [Vector2(200, 220), Vector2(820, 640), Vector2(330, 1180)]:
		for o in [Vector2(-70, 10), Vector2(0, -25), Vector2(70, 10), Vector2(0, 25)]:
			ci.draw_circle(c + o, 70, Color(1, 1, 1, 0.85))
	for b in balloons:
		ToddlerArt.draw_balloon(ci, balloon_pos(b), BALLOON_R, b.color, _time * 2.0 + b.phase)
