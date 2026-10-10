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
	for p in Profiles.profiles:
		grid.add_child(_card(p))


func _card(p: Dictionary) -> Button:
	var color := Color(p.color)
	var b := Button.new()
	b.name = "Profile_" + p.id
	b.custom_minimum_size = Vector2(0, 560)
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
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func():
		Profiles.select(p.id)
		main.goto("books"))
	return b
