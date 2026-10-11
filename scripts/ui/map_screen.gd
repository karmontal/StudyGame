extends Screen
## One book: its units, each with its lessons as a path of numbered stops. Every lesson is open
## so the kids can practise whatever they have at school that day.

var book_id := ""
var color := Color.GRAY


func build() -> void:
	book_id = args.book
	var meta := Content.book_meta(book_id)
	color = Content.subject_color(meta.subject)
	var data := Content.book(book_id)
	var content := page(data.get("title", Content.subject_name(meta.subject)), color)
	for u in data.get("units", []):
		content.add_child(_unit_card(u))


func go_back() -> void:
	main.goto("books")


func _unit_card(u: Dictionary) -> PanelContainer:
	var card := UI.card()
	card.name = "Unit_" + u.id
	var v := UI.vbox(18)
	card.add_child(v)
	var head := UI.hbox(16)
	v.add_child(head)
	var title := UI.label(u.title, 44, color.darkened(0.25), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var possible := 3 * _playable_lessons(u)
	if possible > 0:
		var score := UI.label("%d/%d" % [Profiles.unit_stars(book_id, u), possible], 32, UI.MUTED)
		score.autowrap_mode = TextServer.AUTOWRAP_OFF
		head.add_child(score)
	var i := 0
	for l in u.lessons:
		i += 1
		v.add_child(_lesson_row(u, l, i))
	var unit_qs := Content.unit_questions(book_id, u.id)
	if unit_qs.size() >= 4:
		var open := Content.unit_finished(book_id, u.id)
		var test := UI.button("تحدي الوحدة كاملة" if open else "تحدي الوحدة: خلّص كل دروسها أولاً",
			color.darkened(0.1) if open else Color("#BBBBBB"), 40, 120)
		test.name = "UnitTest_" + u.id
		test.disabled = not open
		test.pressed.connect(func():
			main.goto("quiz", {"questions": unit_qs, "count": 10, "title": u.title, "book": book_id,
				"unit": u.id, "kind": "unit", "back": "map", "back_args": {"book": book_id}}))
		v.add_child(test)
	return card


func _lesson_row(u: Dictionary, l: Dictionary, number: int) -> Button:
	var qs := Content.lesson_questions(book_id, u.id, l.id)
	var key := Profiles.lesson_key(book_id, u.id, l.id)
	var earned := Profiles.stars(key)
	var b := Button.new()
	b.name = "Lesson_%s_%s" % [u.id, l.id]
	b.custom_minimum_size.y = 150
	UI.style_button(b, color.lightened(0.82) if not qs.is_empty() else Color("#EEEEEE"), UI.TEXT)
	var h := UI.hbox(20)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -20
	b.add_child(h)
	var badge := UI.label(str(number), 44, Color.WHITE)
	badge.custom_minimum_size = Vector2(100, 100)
	badge.add_theme_stylebox_override("normal", UI.box(color if earned > 0 else color.lerp(Color.WHITE, 0.35), 50))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var title := UI.label(l.title, 38, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	if qs.is_empty():
		var soon := UI.label("قريباً", 30, UI.MUTED)
		soon.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(soon)
		b.disabled = true
	else:
		var stars := StarRow.make(earned, 40)
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(stars)
		b.pressed.connect(func():
			main.goto("quiz", {"questions": qs, "title": l.title, "lesson_key": key, "book": book_id,
				"unit": key.split("/")[1], "kind": "lesson", "back": "map", "back_args": {"book": book_id}}))
	for c in h.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _playable_lessons(u: Dictionary) -> int:
	var n := 0
	for l in u.lessons:
		if not l.get("questions", []).is_empty():
			n += 1
	return n
