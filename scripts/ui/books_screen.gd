extends Screen
## The kid's subjects (one book each). Books without questions yet show "قريباً".


func build() -> void:
	var p := Profiles.current()
	var content := page("أهلاً %s!" % p.name, Color(p.color))
	content.add_child(_status_card(p))
	var tasks := Sync.assignments_for(p.id)
	if not tasks.is_empty():
		content.add_child(_tasks(tasks, Color(p.color)))
	content.add_child(_challenges(p))
	content.add_child(UI.label("اختار المادة", 44, UI.TEXT))
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
	main.goto("quiz", {"questions": qs, "title": "مراجعة الأخطاء", "kind": "review", "back": "books", "back_args": {}})


## Coins, level with a bar to the next one, and the days-in-a-row streak.
func _status_card(p: Dictionary) -> PanelContainer:
	var info := Profiles.info()
	var xp := int(info.xp)
	var level := Rewards.level_for(xp)
	var card := UI.card()
	card.name = "Status"
	var v := UI.vbox(14)
	card.add_child(v)
	var row := UI.hbox(24)
	v.add_child(row)
	var coins := CoinIcon.with_amount(int(info.coins), 48)
	coins.name = "Coins"
	row.add_child(coins)
	var lvl := UI.label("المستوى %d · %s" % [level, Rewards.level_title(level)], 38, Color(p.color).darkened(0.2))
	lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lvl)
	var streak := Profiles.live_streak()
	var fire := UI.label("%d %s" % [streak, "يوم" if streak <= 1 or streak > 10 else "أيام"] if streak > 0 else "ابدأ سلسلة!", 32, Color.WHITE)
	fire.autowrap_mode = TextServer.AUTOWRAP_OFF
	fire.add_theme_stylebox_override("normal", UI.box(Color("#E67E22") if streak > 0 else UI.MUTED, 30))
	fire.name = "Streak"
	row.add_child(fire)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 26
	bar.max_value = 1.0
	bar.value = Rewards.level_progress(xp)
	bar.add_theme_stylebox_override("background", UI.box(Color("#EEE8DA"), 13))
	bar.add_theme_stylebox_override("fill", UI.box(Color(p.color), 13))
	v.add_child(bar)
	v.add_child(UI.label("باقي %d نقطة للمستوى %d" % [Rewards.XP_PER_LEVEL - xp % Rewards.XP_PER_LEVEL, level + 1], 28, UI.MUTED))
	return card


func _challenges(p: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	# Challenges only use lessons the kid finished (one star is enough).
	var has_questions := not Content.grade_questions(int(p.grade), ["mcq", "tf"], true).is_empty()
	var done := Profiles.daily_done()
	var daily_sub := "ارجع بكرة" if done else ("+%d عملة" % Rewards.DAILY_BONUS if has_questions else "خلّص درس أولاً")
	var daily := _big_button("Daily", "تمّ تحدي اليوم" if done else "تحدي اليوم", daily_sub, Color("#F39C12"))
	daily.disabled = done or not has_questions
	daily.pressed.connect(_start_daily.bind(p))
	grid.add_child(daily)
	var best := int(Profiles.info().speed_best)
	var speed_sub := ("أفضل نتيجة: %d" % best if best > 0 else "60 ثانية") if has_questions else "خلّص درس أولاً"
	var speed := _big_button("Speed", "تحدي السرعة", speed_sub, Color("#E74C3C"))
	speed.disabled = not has_questions
	speed.pressed.connect(func(): main.goto("speed"))
	grid.add_child(speed)
	var badges := _big_button("Badges", "أوسمتي", "%d من %d" % [Profiles.info().badges.size(), Rewards.BADGES.size()], Color("#8E44AD"))
	badges.pressed.connect(func(): main.goto("badges"))
	grid.add_child(badges)
	var album := _big_button("Album", "الملصقات", "%d من %d" % [Profiles.info().stickers.size(), Profiles.sticker_catalog.size()], Color("#16A085"))
	album.pressed.connect(func(): main.goto("album"))
	grid.add_child(album)
	return grid


## Tests the parent assigned from the dashboard, with the real-world reward they promised.
func _tasks(tasks: Array, color: Color) -> PanelContainer:
	var card := UI.card(Color("#FFF7E0"))
	card.name = "Tasks"
	var v := UI.vbox(16)
	card.add_child(v)
	v.add_child(UI.label("مهام من بابا", 44, Color("#B07D00")))
	for a in tasks:
		var done: bool = a.get("done_at") != null
		var qs := Sync.assignment_questions(a)
		var b := UI.button("", Color("#27AE60") if done else color, 36, 150)
		b.name = "Task_" + str(a.id)
		b.disabled = done or qs.is_empty()
		var col := UI.vbox(2)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var sub := "تمّت! بانتظار المكافأة: %s" % a.get("reward", "") if done else \
			"المطلوب %d نجوم · المكافأة: %s" % [int(a.get("min_stars", 1)), a.get("reward", "")]
		for l in [UI.label(str(a.get("title", "")), 40, Color.WHITE), UI.label(sub, 28, Color(1, 1, 1, 0.92))]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(l)
		b.custom_minimum_size.y = 170
		b.pressed.connect(func():
			main.goto("quiz", {"questions": qs, "count": mini(int(a.get("count", 10)), qs.size()),
				"title": str(a.get("title", "")), "kind": "assignment", "lesson_key": "assignment/" + str(a.id),
				"back": "books", "back_args": {}}))
		v.add_child(b)
		if str(a.get("note", "")) != "":
			v.add_child(UI.label(str(a.note), 30, UI.MUTED))
	return card


func _big_button(node_name: String, title: String, sub: String, color: Color) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 200)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, color)
	var v := UI.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	for l in [UI.label(title, 44, Color.WHITE), UI.label(sub, 30, Color(1, 1, 1, 0.9))]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	return b


func _start_daily(p: Dictionary) -> void:
	var qs := Content.daily_questions(int(p.grade), Profiles.today(), p.id)
	if qs.is_empty():
		return
	main.goto("quiz", {"questions": qs, "count": qs.size(), "title": "تحدي اليوم", "kind": "daily",
		"lesson_key": "daily/" + Profiles.today(), "back": "books", "back_args": {}})
