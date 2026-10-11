extends Screen
## The family contest itself: "pass the phone to X", X answers a question from their own grade, the
## scoreboard updates, and at the end everyone sees the ranking and the coins they earned.
## args: players (profile ids), teams (bool), rounds (int), optional rng_seed (tests).

var contest: FamilyContest
var question: Dictionary = {}
var phase := ""  # handoff, question, feedback, results
var earned := {}  # profile id -> coins from finish_round
var _board: HBoxContainer
var _stage: VBoxContainer
var _answered := false


func build() -> void:
	contest = FamilyContest.make(args.get("players", []), bool(args.get("teams", false)),
		int(args.get("rounds", 3)), int(args.get("rng_seed", 0)))
	add_child(Backdrop.make(Color("#16A085"), 360))
	var content := page("مسابقة العيلة", Color("#16A085"))
	_board = UI.hbox(16)
	_board.name = "Board"
	_board.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_board)
	_stage = UI.vbox(28)
	_stage.name = "Stage"
	content.add_child(_stage)
	_show_handoff()


func go_back() -> void:
	main.goto("family", {"players": contest.players, "teams": contest.teams, "rounds": contest.rounds})


func _exit_tree() -> void:
	Sfx.stop_speaking()


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- scoreboard

func _refresh_board() -> void:
	_clear(_board)
	if contest.teams:
		for t in 2:
			_board.add_child(_team_score(t))
		return
	for id in contest.players:
		_board.add_child(_kid_score(id))


func _kid_score(id: String) -> VBoxContainer:
	var p := Profiles.get_profile(id)
	var v := UI.vbox(2)
	v.name = "Score_" + id
	var a := Avatar.make(p.name, Color(p.color), 120 if contest.players.size() <= 4 else 104, id)
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if phase != "results" and id != contest.current_player():
		a.modulate.a = 0.6
	v.add_child(a)
	var l := UI.label(str(contest.points[id]), 40, Color(p.color).darkened(0.25))
	l.name = "Points"
	v.add_child(l)
	return v


func _team_score(t: int) -> PanelContainer:
	var color: Color = FamilyContest.TEAM_COLORS[t]
	var card := UI.card(color)
	card.name = "Team%d" % t
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	card.add_child(v)
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in contest.team_members(t):
		var p := Profiles.get_profile(id)
		row.add_child(Avatar.make(p.name, Color.WHITE, 80, id))
	v.add_child(row)
	var l := UI.label("%s: %d" % [FamilyContest.TEAM_NAMES[t], contest.team_points(t)], 32, Color.WHITE)
	l.name = "Points"
	v.add_child(l)
	return card


# ---------------------------------------------------------------- phases

func _show_handoff() -> void:
	if contest.done():
		_finish()
		return
	phase = "handoff"
	Sfx.stop_speaking()
	_refresh_board()
	_clear(_stage)
	var id := contest.current_player()
	var p := Profiles.get_profile(id)
	var color := Color(p.color)
	_stage.add_child(UI.label("الجولة %d من %d" % [contest.round_number(), contest.rounds], 34, UI.MUTED))
	var card := UI.card()
	_stage.add_child(card)
	var v := UI.vbox(20)
	card.add_child(v)
	var a := Avatar.make(p.name, color, 340, id)
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(a)
	var who := UI.label("دور %s!" % p.name, 72, color.darkened(0.2))
	who.name = "Turn"
	v.add_child(who)
	if contest.teams:
		var t := int(contest.team_of[id])
		v.add_child(UI.label(FamilyContest.TEAM_NAMES[t], 36, FamilyContest.TEAM_COLORS[t]))
	v.add_child(UI.label("مرّروا التلفون لـ%s" % p.name, 32, UI.MUTED))
	var ready := UI.button("يلا!", color, 56, 170)
	ready.name = "Ready"
	ready.pressed.connect(show_question)
	_stage.add_child(ready)


func show_question() -> void:
	phase = "question"
	_answered = false
	_clear(_stage)
	var id := contest.current_player()
	var p := Profiles.get_profile(id)
	question = contest.next_question(id)
	if question.is_empty():
		# This grade has no questions at all: skip the turn without points.
		contest.answer(false)
		_show_handoff()
		return
	if question.type == "picture":
		_build_picture(question)
		return
	var lang := _lang(question)
	var rtl := lang != "en"
	if Profiles.is_young(p):
		var speak := UI.button("اسمع السؤال", Color(p.color).darkened(0.1), 38, 100)
		speak.name = "Speak"
		speak.pressed.connect(func(): Sfx.speak(Sfx.question_text(question, lang), lang))
		_stage.add_child(speak)
	var qcard := UI.card()
	_stage.add_child(qcard)
	var ql := UI.label(str(question.q), 46, UI.TEXT)
	ql.name = "Question"
	ql.custom_minimum_size.y = 160
	qcard.add_child(ql)
	var answers := UI.vbox(20)
	answers.name = "Answers"
	answers.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	_stage.add_child(answers)
	if question.type == "mcq":
		for i in question.choices.size():
			var b := UI.button(str(question.choices[i]), Color.WHITE, 40, 130, UI.TEXT)
			var box := UI.box(Color.WHITE, 32, Color(p.color).lightened(0.3), 4)
			b.add_theme_stylebox_override("normal", box)
			b.add_theme_stylebox_override("hover", box)
			b.name = "Choice%d" % i
			b.pressed.connect(submit.bind(i))
			answers.add_child(b)
	else:
		var row := UI.hbox(28)
		answers.add_child(row)
		for value in [true, false]:
			var text: String = ("صح" if value else "خطأ") if rtl else ("True" if value else "False")
			var b := UI.button(text, UI.GOOD.darkened(0.1) if value else UI.BAD.darkened(0.05), 52, 170)
			b.name = "True" if value else "False"
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(submit.bind(value))
			row.add_child(b)


## The toddler's turn: three big pictures, find the one the voice asks for. Wrong taps just say
## "try again"; finding it gives her the point.
func _build_picture(q: Dictionary) -> void:
	var target: String = q.options[int(q.answer)]
	var key: String = ("w_" if q.kind == "animal" else "wc_") + target
	_stage.add_child(UI.label(ToddlerVoice.PHRASES.get(key, ""), 64, UI.TEXT))
	var again := UI.button("", Color("#E74C3C"), 38, 120)
	again.name = "Speak"
	again.custom_minimum_size.x = 200
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon := SpeakerIcon.make(Color.WHITE, 80)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	again.add_child(icon)
	again.pressed.connect(func(): ToddlerVoice.say(key))
	_stage.add_child(again)
	var row := UI.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(row)
	for i in q.options.size():
		var opt: String = q.options[i]
		var painter: Callable
		if q.kind == "animal":
			painter = func(ci: CanvasItem, r: Rect2): ToddlerArt.draw_picture(ci, ToddlerArt.picture(opt), [], ToddlerArt.fit(r), 8.0)
		else:
			painter = func(ci: CanvasItem, r: Rect2): ToddlerArt.draw_ball(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.42, ToddlerArt.color_by_id(opt).color)
		var b := ToddlerButton.make("Pic_%d" % i, Vector2(300, 300), Color("#FFF3D6"), painter)
		b.pressed.connect(tap_picture.bind(i))
		row.add_child(b)
	ToddlerVoice.say(key)


func tap_picture(i: int) -> void:
	if _answered:
		return
	if i != int(question.answer):
		Sfx.play("boing")
		ToddlerVoice.say("try")
		return
	_answered = true
	Sfx.play("correct")
	ToddlerVoice.say("bravo")
	var id := contest.answer(true)
	_show_feedback(id, true, "")


func submit(choice) -> void:
	if _answered:
		return
	_answered = true
	var ok: bool = (choice == question.answer) if question.type == "tf" else (int(choice) == int(question.answer))
	Sfx.play("correct" if ok else "wrong")
	var id := contest.answer(ok, str(question.get("key", "")))
	var right := ""
	if not ok:
		if question.type == "mcq":
			right = str(question.choices[int(question.answer)])
		else:
			right = "صح" if question.answer else "خطأ"
	_show_feedback(id, ok, right)


func _show_feedback(id: String, ok: bool, right: String) -> void:
	phase = "feedback"
	_refresh_board()
	_clear(_stage)
	var p := Profiles.get_profile(id)
	var card := UI.card(UI.GOOD if ok else Color("#FDEDEC"))
	card.name = "Feedback"
	_stage.add_child(card)
	var v := UI.vbox(12)
	card.add_child(v)
	if ok:
		v.add_child(UI.label("صح! نقطة لـ%s" % p.name, 56, Color.WHITE))
	else:
		v.add_child(UI.label("مش هالمرة", 52, UI.BAD))
		v.add_child(UI.label("الجواب الصحيح: %s" % right, 38, UI.TEXT))
	var next := UI.button("النتيجة" if contest.done() else "التالي", Color("#16A085"), 48, 150)
	next.name = "Next"
	next.pressed.connect(_show_handoff)
	_stage.add_child(next)


## Everyone's answers go through finish_round (coins, badges, the dashboard); the toddler's don't,
## her games have no coins.
func _finish() -> void:
	phase = "results"
	Sfx.stop_speaking()
	var current := Profiles.current_id
	for id in contest.players:
		if FamilyContest.is_toddler(id) or contest.results[id].is_empty():
			continue
		Profiles.select(id)
		earned[id] = int(Profiles.finish_round("family", "", 0, contest.results[id]).coins)
	Profiles.select(current)
	Sfx.play("fanfare")
	_refresh_board()
	_clear(_stage)
	var winners := contest.winners()
	var title := ""
	if contest.teams:
		title = "تعادل! الفريقين أبطال" if winners.size() > 1 else "%s فاز!" % FamilyContest.TEAM_NAMES[winners[0]]
	elif winners.size() == contest.players.size():
		title = "تعادل! كلكم أبطال"
	else:
		var names: Array[String] = []
		for id in winners:
			names.append(str(Profiles.get_profile(id).name))
		title = ("الفائز: %s" if names.size() == 1 else "الفائزين: %s") % "، ".join(names)
	var head := UI.label(title, 60, Color("#16A085").darkened(0.2))
	head.name = "Winner"
	_stage.add_child(head)
	var list := UI.vbox(16)
	list.name = "Ranking"
	_stage.add_child(list)
	for id in contest.ranking():
		list.add_child(_result_row(id, winners))
	var again := UI.button("كمان مرة!", Color("#16A085"), 48, 140)
	again.name = "Again"
	again.pressed.connect(func(): main.goto("family_play", {"players": contest.players, "teams": contest.teams, "rounds": contest.rounds}))
	_stage.add_child(again)
	var home := UI.button("رجوع للبداية", UI.MUTED, 40, 120)
	home.name = "Home"
	home.pressed.connect(func(): main.goto("profiles"))
	_stage.add_child(home)


func _result_row(id: String, winners: Array) -> PanelContainer:
	var p := Profiles.get_profile(id)
	var color := Color(p.color)
	var won: bool = winners.has(int(contest.team_of.get(id, -1))) if contest.teams else winners.has(id)
	var card := UI.card(Color("#FFF7E0") if won else UI.CARD)
	card.name = "Row_" + id
	var row := UI.hbox(24)
	card.add_child(row)
	row.add_child(Avatar.make(p.name, color, 120, id))
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UI.label(p.name, 44, color.darkened(0.25), HORIZONTAL_ALIGNMENT_LEFT))
	var pts := int(contest.points[id])
	v.add_child(UI.label("%d %s" % [pts, "نقطة" if pts == 1 or pts > 10 else "نقاط"], 32, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if earned.has(id):
		var coins := CoinIcon.with_amount(int(earned[id]), 36)
		coins.name = "Coins"
		row.add_child(coins)
	if won:
		row.add_child(Medal.make(UI.STAR, true, 90))
	return card


func _lang(q: Dictionary) -> String:
	var key: String = q.get("key", "")
	return Content.book_lang(key.split("/")[0]) if key != "" else "ar"
