extends Screen
## The kid's subjects (one book each). Books without questions yet show "قريباً".


func build() -> void:
	var p := Profiles.current()
	var content := page("أهلاً %s! اختار المادة" % p.name, Color(p.color))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 32)
	content.add_child(grid)
	for b in Content.books_for_grade(int(p.grade)):
		grid.add_child(_book_card(b))
	var review := Profiles.review_keys()
	if not review.is_empty():
		var btn := UI.button("راجع أخطائك (%d سؤال)" % review.size(), UI.BAD, 44, 140)
		btn.name = "Review"
		btn.pressed.connect(_start_review.bind(review))
		content.add_child(btn)


func _book_card(meta: Dictionary) -> Button:
	var color := Content.subject_color(meta.subject)
	var has_data := Content.has_book_data(meta.id)
	var b := Button.new()
	b.name = "Book_" + meta.id
	b.custom_minimum_size = Vector2(0, 380)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, color if has_data else color.lerp(Color("#CCCCCC"), 0.6))
	var v := UI.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	v.add_child(UI.label(Content.subjects.get(meta.subject, {}).get("icon", ""), 96, Color(1, 1, 1, 0.9)))
	v.add_child(UI.label(Content.subject_name(meta.subject), 46, Color.WHITE))
	if has_data:
		var data := Content.book(meta.id)
		var earned := 0
		var possible := 0
		for u in data.get("units", []):
			earned += Profiles.unit_stars(meta.id, u)
			for l in u.lessons:
				if not l.get("questions", []).is_empty():
					possible += 3
		v.add_child(UI.label("%d / %d نجمة" % [earned, possible], 32, Color(1, 1, 1, 0.85)))
		b.pressed.connect(func(): main.goto("map", {"book": meta.id}))
	else:
		v.add_child(UI.label("قريباً", 34, Color(1, 1, 1, 0.9)))
		b.disabled = true
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _start_review(keys: Array[String]) -> void:
	var qs: Array[Dictionary] = []
	for k in keys:
		var q := Content.question_by_key(k)
		if not q.is_empty():
			qs.append(q)
	if qs.is_empty():
		return
	main.goto("quiz", {"questions": qs, "title": "مراجعة الأخطاء", "back": "books", "back_args": {}})
