extends ToddlerScreen
## "يلا نرتاح": after ten minutes of toddler play. A sleeping moon, and a long-press button for a
## parent to continue (which starts a new ten minutes). The exit (long press) goes to the profiles.

var _moon := PackedVector2Array()


func setup() -> void:
	counts_time = false
	bg_color = Color("#1A2340")
	var parts := Geometry2D.clip_polygons(ToddlerArt.circle(Vector2(540, 640), 280, 72), ToddlerArt.circle(Vector2(680, 540), 250, 72))
	for p in parts:
		if p.size() > _moon.size():
			_moon = p
	var sky := Control.new()
	sky.name = "Sky"
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.draw.connect(func(): _paint(sky))
	add_child(sky)
	var title := UI.label("يلا نرتاح", 96, Color("#FFF59D"))
	title.name = "RestTitle"
	title.position = Vector2(0, 1080)
	title.size = Vector2(1080, 160)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var cont := ToddlerHold.make("play", 220.0, Color("#43A047"))
	cont.name = "Continue"
	cont.position = Vector2(430, 1380)
	cont.held.connect(resume)
	add_child(cont)
	var hint := UI.label("للأهل: اضغط مطوّلاً لتكمل اللعب", 30, Color("#B0BEC5"))
	hint.name = "ContinueHint"
	hint.position = Vector2(0, 1620)
	hint.size = Vector2(1080, 60)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	ToddlerVoice.say("rest")


## A parent's long press: a fresh ten minutes.
func resume() -> void:
	ToddlerScreen.play_seconds = 0.0
	_go("toddler")


func leave() -> void:
	_go("profiles")


func go_back() -> void:
	pass


func _paint(ci: CanvasItem) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		var p := Vector2(rng.randf_range(20, 1060), rng.randf_range(200, 1900))
		if p.distance_to(Vector2(540, 640)) < 330 or (p.y > 1060 and p.y < 1260) or (p.y > 1340 and p.y < 1720 and absf(p.x - 540) < 330):
			continue
		ci.draw_colored_polygon(ToddlerArt.star(p, rng.randf_range(10, 22), 5), Color(1, 1, 0.8, rng.randf_range(0.4, 0.9)))
	ci.draw_colored_polygon(ToddlerArt.circle(Vector2(540, 640), 320, 72), Color(1, 1, 0.8, 0.06))
	var closed := _moon.duplicate()
	closed.append(_moon[0])
	ci.draw_polyline(closed, Color("#F9A825"), 16.0, true)
	ci.draw_colored_polygon(_moon, Color("#FFF176"))
	# A sleeping face: a closed eye, a rosy cheek and a little smile.
	ci.draw_polyline(ToddlerArt.arc(Vector2(380, 590), 45, PI * 0.1, PI * 0.9), ToddlerArt.OUTLINE, 10.0, true)
	ci.draw_circle(Vector2(350, 680), 30, Color(1, 0.6, 0.6, 0.6))
	ci.draw_polyline(ToddlerArt.arc(Vector2(420, 700), 50, PI * 0.25, PI * 0.75), ToddlerArt.OUTLINE, 10.0, true)
	# Floating "z z z" drawn as lines.
	for k in 3:
		var o := Vector2(700 + k * 80, 400 - k * 75)
		var s := 34.0 + k * 12.0
		ci.draw_polyline(PackedVector2Array([o, o + Vector2(s, 0), o + Vector2(0, s), o + Vector2(s, s)]), Color("#B3E5FC"), 9.0, true)
