extends Screen
## Family contest setup: who plays, each for themselves or two teams, and how many rounds.
## args (optional, from "play again"): players, teams, rounds.

var picked := {}  # profile id -> bool
var teams := false
var rounds := 3
var _picks: GridContainer
var _options: VBoxContainer


func build() -> void:
	add_child(Backdrop.make(Color("#16A085"), 430))
	var content := page("مسابقة العيلة", Color("#16A085"))
	content.add_child(UI.label("كل واحد بيجاوب أسئلة من صفّه، وكل جواب صح إله نقطة وحدة. مرّروا التلفون بينكم!", 32, UI.MUTED))
	var chosen: Array = args.get("players", [])
	for p in Profiles.profiles:
		picked[p.id] = chosen.is_empty() or chosen.has(p.id)
	teams = bool(args.get("teams", false))
	rounds = int(args.get("rounds", 3))
	content.add_child(UI.label("مين بيلعب؟", 44, UI.TEXT))
	_picks = GridContainer.new()
	_picks.columns = 3
	_picks.add_theme_constant_override("h_separation", 24)
	_picks.add_theme_constant_override("v_separation", 24)
	content.add_child(_picks)
	_options = UI.vbox(24)
	content.add_child(_options)
	_refresh()


func _refresh() -> void:
	for c in _picks.get_children():
		_picks.remove_child(c)
		c.queue_free()
	for p in Profiles.profiles:
		_picks.add_child(_pick_button(p))
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	_options.add_child(UI.label("طريقة اللعب", 44, UI.TEXT))
	var modes := UI.hbox(24)
	modes.add_child(_choice("Mode_solo", "كل واحد لحاله", not teams, func(): teams = false))
	modes.add_child(_choice("Mode_teams", "فريقين", teams, func(): teams = true))
	_options.add_child(modes)
	if teams:
		_options.add_child(_teams_preview())
	_options.add_child(UI.label("كم جولة؟", 44, UI.TEXT))
	var counts := UI.hbox(24)
	for n in [3, 5]:
		counts.add_child(_choice("Rounds_%d" % n, "%d جولات" % n, rounds == n, func(): rounds = n))
	_options.add_child(counts)
	var start := UI.button("يلا نبلش!", Color("#16A085"), 52, 160)
	start.name = "Start"
	start.disabled = players().size() < 2
	start.pressed.connect(start_game)
	_options.add_child(start)
	if start.disabled:
		_options.add_child(UI.label("اختاروا لاعبين على الأقل", 30, UI.MUTED))


func players() -> Array[String]:
	var out: Array[String] = []
	for p in Profiles.profiles:
		if picked.get(p.id, false):
			out.append(p.id)
	return out


func start_game() -> void:
	if players().size() < 2:
		return
	main.goto("family_play", {"players": players(), "teams": teams, "rounds": rounds})


func _pick_button(p: Dictionary) -> Button:
	var on: bool = picked.get(p.id, false)
	var color := Color(p.color)
	var b := Button.new()
	b.name = "Pick_" + p.id
	b.custom_minimum_size = Vector2(0, 280)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(b, Color.WHITE)
	var box := UI.box(Color.WHITE if on else Color("#F1EDE4"), 36, color if on else Color.TRANSPARENT, 6 if on else 0)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	var v := UI.vbox(6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var avatar := Avatar.make(p.name, color, 160, p.id)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(avatar)
	v.add_child(UI.label(p.name, 40, color.darkened(0.25) if on else UI.MUTED))
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate.a = 1.0 if on else 0.55
	b.pressed.connect(func():
		picked[p.id] = not picked.get(p.id, false)
		_refresh.call_deferred())
	return b


func _choice(node_name: String, text: String, on: bool, pick: Callable) -> Button:
	var b := UI.button(text, Color("#16A085") if on else Color.WHITE, 38, 120, Color.WHITE if on else UI.TEXT)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		pick.call()
		_refresh.call_deferred())
	return b


func _teams_preview() -> PanelContainer:
	var card := UI.card()
	card.name = "TeamsPreview"
	var v := UI.vbox(16)
	card.add_child(v)
	var split := FamilyContest.split_teams(players())
	for t in 2:
		var row := UI.hbox(16)
		var name_label := UI.label(FamilyContest.TEAM_NAMES[t], 34, FamilyContest.TEAM_COLORS[t])
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size.x = 300
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)
		for id in players():
			if int(split.get(id, -1)) == t:
				var p := Profiles.get_profile(id)
				row.add_child(Avatar.make(p.name, Color(p.color), 100, id))
		v.add_child(row)
	v.add_child(UI.label("الفريقين بياخدوا نفس عدد الأدوار", 28, UI.MUTED))
	return card
