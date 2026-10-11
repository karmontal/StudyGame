extends Screen
## "Who is playing today?" — one big card per kid.


func build() -> void:
	add_child(Backdrop.make(Color("#F7B500"), 430))
	var content := page("مين بيلعب اليوم؟", UI.TEXT, false)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 32)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var leader := _week_leader()
	for p in Profiles.profiles:
		if p.get("toddler", false):
			continue
		grid.add_child(_card(p, p.id == leader))
	for p in Profiles.profiles:
		if p.get("toddler", false):
			content.add_child(_toddler_card(p))
	content.add_child(UI.label("العملات تنحسب كل أسبوع من جديد، يوم الإثنين", 30, UI.MUTED))
	var row := UI.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_sound_toggle())
	row.add_child(_parents_button())
	content.add_child(row)


## The parents' settings open only after holding the button, so the kids don't wander in.
func _parents_button() -> Button:
	var b := UI.button("للأهل (اضغط مطوّلاً)", Color("#7F8C8D"), 30, 90)
	b.name = "Parents"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 420
	b.button_down.connect(func():
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(b) and b.is_inside_tree() and b.button_pressed:
			main.goto("parents"))
	return b


## Sound on/off for effects and reading aloud.
func _sound_toggle() -> Button:
	var on := Settings.sound_on()
	var b := UI.button("", Color("#16A085") if on else Color("#95A5A6"), 36, 110)
	b.name = "Sound"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 420
	var row := UI.hbox(16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(SpeakerIcon.make(Color.WHITE, 60, not on))
	var l := UI.label("الصوت شغّال" if on else "الصوت مطفي", 36, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.add_child(row)
	b.pressed.connect(func():
		Settings.set_value("sound", not Settings.sound_on())
		main.goto("profiles"))
	return b


## The kid with the most coins this week, or "" when nobody has played yet.
func _week_leader() -> String:
	var best := 0
	var leader := ""
	for p in Profiles.profiles:
		var c := Profiles.week_coins(p.id)
		if c > best:
			best = c
			leader = p.id
	return leader


func _card(p: Dictionary, leader: bool) -> Button:
	var color := Color(p.color)
	var b := Button.new()
	b.name = "Profile_" + p.id
	b.custom_minimum_size = Vector2(0, 700)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, UI.CARD)
	b.add_theme_stylebox_override("pressed", UI.box(color.lerp(Color.WHITE, 0.8)))
	# Colored band across the top of the card, with the round picture sitting on its edge.
	var band := Panel.new()
	var band_box := UI.box(color, 36)
	band_box.corner_radius_bottom_left = 0
	band_box.corner_radius_bottom_right = 0
	band.add_theme_stylebox_override("panel", band_box)
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = 170
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(band)
	var v := UI.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 40
	v.offset_bottom = -24
	b.add_child(v)
	var avatar := Avatar.make(p.name, color.darkened(0.1), 270, p.id)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(avatar)
	v.add_child(UI.label(p.name, 62, color.darkened(0.25)))
	var grade := UI.label(UI.grade_name(int(p.grade)), 30, color.darkened(0.25))
	grade.autowrap_mode = TextServer.AUTOWRAP_OFF
	grade.add_theme_stylebox_override("normal", UI.box(color.lerp(Color.WHITE, 0.82), 24))
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grade)
	var stats := UI.hbox(20)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	var level := Rewards.level_for(int(Profiles.info(p.id).xp))
	var lvl := UI.label("المستوى %d" % level, 30, UI.MUTED)
	lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.add_child(lvl)
	var week := CoinIcon.with_amount(Profiles.week_coins(p.id), 32)
	week.name = "Week"
	stats.add_child(week)
	v.add_child(stats)
	if leader:
		var crown := UI.label("الأول هالأسبوع", 28, Color.WHITE)
		crown.name = "Leader"
		crown.autowrap_mode = TextServer.AUTOWRAP_OFF
		crown.add_theme_stylebox_override("normal", UI.box(UI.STAR, 26))
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(crown)
	_ignore_taps(v)
	b.pressed.connect(func():
		Profiles.select(p.id)
		main.goto("books"))
	return b


## The little one's card: wide and bright, straight into her picture games (no reading needed).
func _toddler_card(p: Dictionary) -> Button:
	var color := Color(p.color)
	var b := Button.new()
	b.name = "Profile_" + p.id
	b.custom_minimum_size = Vector2(0, 340)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, Color("#FFF1D6"))
	b.get_theme_stylebox("normal").border_color = color
	b.get_theme_stylebox("normal").set_border_width_all(6)
	var row := UI.hbox(36)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40
	row.offset_right = -40
	b.add_child(row)
	var avatar := Avatar.make(p.name, color, 270, p.id)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)
	var v := UI.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UI.label(p.name, 72, color.darkened(0.15), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UI.label("ألوان وأشكال وحيوانات", 34, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 14)
	for c in UI.PAIR_COLORS:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(44, 44)
		d.add_theme_stylebox_override("panel", UI.box(c, 22))
		dots.add_child(d)
	v.add_child(dots)
	_ignore_taps(row)
	b.pressed.connect(func():
		Profiles.select(p.id)
		main.goto("toddler"))
	return b


func _ignore_taps(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		if c is Control:
			_ignore_taps(c)
