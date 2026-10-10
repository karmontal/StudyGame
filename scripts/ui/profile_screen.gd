extends Screen
## "Who is playing today?" — one big card per kid.


func build() -> void:
	var content := page("مين بيلعب اليوم؟", UI.TEXT, false)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 36)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	var leader := _week_leader()
	for p in Profiles.profiles:
		grid.add_child(_card(p, p.id == leader))
	content.add_child(UI.label("العملات تنحسب كل أسبوع من جديد، يوم الإثنين", 30, UI.MUTED))


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
	var v := UI.vbox(12)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var avatar := Avatar.make(p.name, color, 240)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(avatar)
	v.add_child(UI.label(p.name, 64, color.darkened(0.2)))
	v.add_child(UI.label(UI.grade_name(int(p.grade)), 36, UI.MUTED))
	var level := Rewards.level_for(int(Profiles.info(p.id).xp))
	v.add_child(UI.label("المستوى %d" % level, 32, color.darkened(0.2)))
	var week := CoinIcon.with_amount(Profiles.week_coins(p.id), 34)
	week.alignment = BoxContainer.ALIGNMENT_CENTER
	week.name = "Week"
	v.add_child(week)
	if leader:
		var crown := UI.label("الأول هالأسبوع", 30, Color.WHITE)
		crown.name = "Leader"
		crown.autowrap_mode = TextServer.AUTOWRAP_OFF
		crown.add_theme_stylebox_override("normal", UI.box(Color("#F7B500"), 26))
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(crown)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func():
		Profiles.select(p.id)
		main.goto("books"))
	return b
