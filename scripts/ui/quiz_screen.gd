extends Screen
## A round of questions with the reward on top (picture for young kids, lock for older ones).
## args: questions (Array[Dictionary]), title, optional count, lesson_key, book, back, back_args.

var session: QuizSession
var young := true
var color := Color.GRAY
var reward: Control
var progress_label: Label
var question_label: Label
var answers: VBoxContainer
var feedback: PanelContainer
var _answered := false
var _rtl := true
var _coin_label: Label
var _round_coins := 0
var _combo := 0


func build() -> void:
	var p := Profiles.current()
	young = Profiles.is_young(p)
	color = Color(p.color)
	session = QuizSession.new(args.questions, int(args.get("count", QuizSession.MAX_QUESTIONS)))
	var content := page(args.get("title", ""), color)
	var top := UI.hbox(16)
	content.add_child(top)
	progress_label = UI.label("", 34, UI.MUTED)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(progress_label)
	var coins := CoinIcon.with_amount(0, 36)
	coins.name = "RoundCoins"
	_coin_label = coins.get_node("Amount")
	top.add_child(coins)
	var seed_value := hash(str(args.get("lesson_key", args.get("title", ""))))
	if young:
		reward = PictureReveal.make(session.count(), seed_value)
	else:
		reward = LockPanel.make(session.count(), seed_value)
	reward.name = "Reward"
	content.add_child(reward)
	if young:
		content.add_child(_speak_button())
	var qcard := UI.card()
	content.add_child(qcard)
	question_label = UI.label("", 50 if young else 46, UI.TEXT)
	question_label.name = "Question"
	question_label.custom_minimum_size.y = 160
	qcard.add_child(question_label)
	answers = UI.vbox(22)
	answers.name = "Answers"
	content.add_child(answers)
	feedback = UI.card()
	feedback.name = "Feedback"
	content.add_child(feedback)
	_show_question()


func go_back() -> void:
	main.goto(args.get("back", "books"), args.get("back_args", {}))


func _exit_tree() -> void:
	Sfx.stop_speaking()


## Young kids get a speaker button that reads the question and its choices out loud.
func _speak_button() -> VBoxContainer:
	var box := UI.vbox(6)
	var b := UI.button("", color.darkened(0.1), 40, 110)
	b.name = "Speak"
	var row := UI.hbox(18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(SpeakerIcon.make(Color.WHITE, 72))
	var l := UI.label("اسمع السؤال", 40, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.add_child(row)
	box.add_child(b)
	var hint := UI.label("", 28, UI.MUTED)
	hint.name = "SpeakHint"
	hint.visible = false
	box.add_child(hint)
	b.pressed.connect(func():
		var q := session.current()
		var lang := _lang(q)
		var ok := Sfx.speak(Sfx.question_text(q, lang), lang)
		hint.visible = not ok
		if not ok:
			hint.text = "الصوت مطفي" if not Settings.sound_on() else \
				"ما في صوت %s على الجهاز: نزّل Google Text-to-Speech من المتجر" % ("عربي" if lang != "en" else "إنجليزي"))
	return box


func _show_question() -> void:
	Sfx.stop_speaking()
	_answered = false
	feedback.visible = false
	_clear(answers)
	var q := session.current()
	_rtl = _lang(q) != "en"
	var dir := Control.LAYOUT_DIRECTION_RTL if _rtl else Control.LAYOUT_DIRECTION_LTR
	answers.layout_direction = dir
	feedback.layout_direction = dir
	question_label.text = str(q.q)
	progress_label.text = "سؤال %d من %d" % [session.index + 1, session.count()]
	match q.type:
		"mcq":
			_build_mcq(q)
		"tf":
			_build_tf(q)
		"match":
			_build_match(q)
		"order":
			_build_order(q)


func _lang(q: Dictionary) -> String:
	var key: String = q.get("key", "")
	return Content.book_lang(key.split("/")[0]) if key != "" else "ar"


func _choice_button(text: String) -> Button:
	var b := UI.button(text, Color.WHITE, 44 if young else 40, 130, UI.TEXT)
	b.add_theme_stylebox_override("normal", UI.box(Color.WHITE, 32, color.lightened(0.3), 4))
	b.add_theme_stylebox_override("hover", UI.box(Color.WHITE, 32, color.lightened(0.3), 4))
	return b


func _build_mcq(q: Dictionary) -> void:
	var buttons: Array[Button] = []
	for i in q.choices.size():
		var b := _choice_button(str(q.choices[i]))
		b.name = "Choice%d" % i
		buttons.append(b)
		answers.add_child(b)
		b.pressed.connect(func():
			if _answered:
				return
			var ok := _submit(i)
			UI.style_button(b, UI.GOOD if ok else UI.BAD)
			if not ok:
				UI.style_button(buttons[int(q.answer)], UI.GOOD))


func _build_tf(q: Dictionary) -> void:
	var row := UI.hbox(28)
	answers.add_child(row)
	var labels := ["صح", "خطأ"] if _rtl else ["True", "False"]
	var buttons: Array[Button] = []
	for value in [true, false]:
		var b := UI.button(labels[0] if value else labels[1], UI.GOOD.darkened(0.1) if value else UI.BAD.darkened(0.05), 52, 170)
		b.name = "True" if value else "False"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
		row.add_child(b)
		b.pressed.connect(func():
			if _answered:
				return
			var ok := _submit(value)
			for other in buttons:
				if other != b:
					other.modulate.a = 0.35
			if not ok:
				b.modulate.a = 0.35
				buttons[0 if q.answer else 1].modulate.a = 1.0)


func _build_match(q: Dictionary) -> void:
	answers.add_child(UI.label("اختار من اليمين ثم من اليسار" if _rtl else "Tap one on each side to pair them", 30, UI.MUTED))
	var row := UI.hbox(28)
	answers.add_child(row)
	var left_col := UI.vbox(18)
	var right_col := UI.vbox(18)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_col)
	row.add_child(right_col)
	var n: int = q.left.size()
	var assign: Array = []
	assign.resize(n)
	assign.fill(-1)
	var state := {"selected": -1}
	var lefts: Array[Button] = []
	var rights: Array[Button] = []
	var check := UI.button("تحقق" if _rtl else "Check", color, 44, 120)
	check.name = "Check"
	check.disabled = true
	var refresh := func():
		for i in n:
			var c: Color = UI.PAIR_COLORS[i % UI.PAIR_COLORS.size()]
			if assign[i] >= 0:
				UI.style_button(lefts[i], c)
			elif state.selected == i:
				UI.style_button(lefts[i], c.lightened(0.4))
			else:
				UI.style_button(lefts[i], Color("#ECEFF1"), UI.TEXT)
		for j in n:
			var owner := assign.find(j)
			if owner >= 0:
				UI.style_button(rights[j], UI.PAIR_COLORS[owner % UI.PAIR_COLORS.size()])
			else:
				UI.style_button(rights[j], Color("#ECEFF1"), UI.TEXT)
		check.disabled = assign.has(-1)
	for i in n:
		var b := UI.button(str(q.left[i]), Color("#ECEFF1"), 36, 120, UI.TEXT)
		b.name = "Left%d" % i
		lefts.append(b)
		left_col.add_child(b)
		b.pressed.connect(func():
			if _answered:
				return
			state.selected = i
			assign[i] = -1
			refresh.call())
	for j in n:
		var b := UI.button(str(q.right[j]), Color("#ECEFF1"), 36, 120, UI.TEXT)
		b.name = "Right%d" % j
		rights.append(b)
		right_col.add_child(b)
		b.pressed.connect(func():
			if _answered or state.selected < 0:
				return
			var prev := assign.find(j)
			if prev >= 0:
				assign[prev] = -1
			assign[state.selected] = j
			state.selected = -1
			refresh.call())
	answers.add_child(check)
	check.pressed.connect(func():
		if _answered:
			return
		_submit(assign.duplicate())
		for i in n:
			var right_ok: bool = q.right_origin[assign[i]] == i
			UI.style_button(lefts[i], UI.GOOD if right_ok else UI.BAD)
			UI.style_button(rights[assign[i]], UI.GOOD if right_ok else UI.BAD))
	refresh.call()


func _build_order(q: Dictionary) -> void:
	answers.add_child(UI.label("اضغط عليها بالترتيب الصحيح" if _rtl else "Tap them in the right order", 30, UI.MUTED))
	var picked: Array = []
	var buttons: Array[Button] = []
	var texts: Array = q.shuffled
	for k in texts.size():
		var b := _choice_button(str(texts[k]))
		b.name = "Item%d" % k
		buttons.append(b)
		answers.add_child(b)
		b.pressed.connect(func():
			if _answered or picked.has(k):
				return
			picked.append(k)
			b.text = "%d)  %s" % [picked.size(), texts[k]]
			UI.style_button(b, color)
			if picked.size() == texts.size():
				var ok := _submit(picked.duplicate())
				for pos in picked.size():
					var good: bool = q.shuffled_origin[picked[pos]] == pos
					UI.style_button(buttons[picked[pos]], UI.GOOD if good or ok else UI.BAD))
	var reset := UI.button("من جديد" if _rtl else "Start again", Color("#95A5A6"), 34, 100)
	reset.name = "Reset"
	answers.add_child(reset)
	reset.pressed.connect(func():
		if _answered:
			return
		picked.clear()
		for k in buttons.size():
			buttons[k].text = str(texts[k])
			buttons[k].add_theme_stylebox_override("normal", UI.box(Color.WHITE, 32, color.lightened(0.3), 4))
			buttons[k].add_theme_stylebox_override("hover", UI.box(Color.WHITE, 32, color.lightened(0.3), 4))
			buttons[k].add_theme_stylebox_override("pressed", UI.box(Color.WHITE.darkened(0.1), 32)))


## Checks the answer, updates the reward and shows the feedback card. Returns whether it was right.
func _submit(value: Variant) -> bool:
	_answered = true
	var q := session.current()
	var i := session.index
	var ok := session.answer(value)
	if ok:
		_combo += 1
		_round_coins += Rewards.COIN_PER_CORRECT + (Rewards.COMBO_BONUS if _combo >= 3 else 0)
		_coin_label.text = "+%d" % _round_coins
	else:
		_combo = 0
	if young:
		if ok:
			(reward as PictureReveal).reveal(i)
	else:
		(reward as LockPanel).set_digit(i, ok)
	_play(ok)
	_show_feedback(q, ok)
	return ok


func _show_feedback(q: Dictionary, ok: bool) -> void:
	_clear(feedback)
	feedback.add_theme_stylebox_override("panel", UI.box(UI.GOOD.lightened(0.75) if ok else UI.BAD.lightened(0.78), 36))
	var v := UI.vbox(14)
	feedback.add_child(v)
	var praise := ["أحسنت!", "ممتاز!", "رائع!", "برافو عليك!"]
	if ok:
		v.add_child(UI.label(praise[randi() % praise.size()] if _rtl else "Well done!", 52, UI.GOOD.darkened(0.3)))
		if _combo >= 3:
			var combo := UI.label("سلسلة %d صح ورا بعض! مكافأة +%d" % [_combo, Rewards.COMBO_BONUS], 36, Color("#E67E22"))
			combo.name = "Combo"
			v.add_child(combo)
	else:
		v.add_child(UI.label("ولا يهمك، الإجابة الصحيحة:" if _rtl else "Not quite. The right answer:", 40, UI.BAD.darkened(0.2)))
		v.add_child(UI.label(QuizSession.correct_text(q), 42, UI.TEXT))
	if str(q.get("explain", "")) != "":
		v.add_child(UI.label(str(q.explain), 34, UI.MUTED))
	var last := session.index + 1 >= session.count()
	var next := UI.button(("النتيجة" if last else "التالي") if _rtl else ("Results" if last else "Next"), color, 44, 120)
	next.name = "Next"
	v.add_child(next)
	next.pressed.connect(_next)
	feedback.visible = true
	await get_tree().process_frame
	var scroll := feedback.get_parent().get_parent().get_parent() as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(next)


## Removes children right away (not just queue_free) so new nodes can reuse their names.
func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _next() -> void:
	session.next()
	if session.is_done():
		_finish()
	else:
		_show_question()


func _finish() -> void:
	var earned := session.stars()
	var summary := Profiles.finish_round(args.get("kind", "lesson"), args.get("lesson_key", ""), earned,
		session.results, args.get("book", ""), args.get("unit", ""))
	main.goto("result", {"stars": earned, "correct": session.correct_count(), "total": session.count(),
		"quiz_args": args, "summary": summary})


func _play(ok: bool) -> void:
	Sfx.play("correct" if ok else "wrong")
