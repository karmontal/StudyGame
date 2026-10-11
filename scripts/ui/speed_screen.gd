extends Screen
## Speed challenge: as many right answers as possible before the clock runs out (multiple choice and
## true/false from the lessons the kid finished). Each answer moves straight to the next question.

const SECONDS_OLD := 60.0
const SECONDS_YOUNG := 90.0
const RESULTS_SCRIPT := preload("res://scripts/ui/result_screen.gd")

var time_left := 60.0
var running := false
var results: Array[Dictionary] = []
var color := Color.GRAY
var _pool: Array[Dictionary] = []
var _current: Dictionary = {}
var _content: VBoxContainer
var _timer_label: Label
var _score_label: Label
var _question_label: Label
var _answers: VBoxContainer
var _locked := false
var _sfx: AudioStreamPlayer


func build() -> void:
	var p := Profiles.current()
	color = Color(p.color)
	time_left = SECONDS_YOUNG if Profiles.is_young(p) else SECONDS_OLD
	_pool = Content.grade_questions(int(p.grade), ["mcq", "tf"], true)
	_pool.shuffle()
	_content = page("تحدي السرعة", color)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_show_intro()


func go_back() -> void:
	main.goto("books")


func _show_intro() -> void:
	_clear(_content)
	_content.add_child(UI.label("جاوب أكبر عدد من الأسئلة قبل ما يخلص الوقت!", 46, UI.TEXT))
	_content.add_child(UI.label("عندك %d ثانية. كل إجابة صح = %d عملات." % [int(time_left), Rewards.COIN_PER_CORRECT], 36, UI.MUTED))
	var best := int(Profiles.info().speed_best)
	if best > 0:
		_content.add_child(UI.label("أفضل نتيجة لك: %d" % best, 40, color.darkened(0.2)))
	var go := UI.button("يلا نبدأ!", color, 52, 160)
	go.name = "Start"
	go.pressed.connect(start)
	_content.add_child(go)


func start() -> void:
	_clear(_content)
	results.clear()
	var top := UI.hbox(20)
	_content.add_child(top)
	_timer_label = UI.label("", 56, UI.BAD)
	_timer_label.name = "Timer"
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_timer_label)
	_score_label = UI.label("0", 56, UI.GOOD.darkened(0.2))
	_score_label.name = "Score"
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_score_label)
	var card := UI.card()
	_content.add_child(card)
	_question_label = UI.label("", 46, UI.TEXT)
	_question_label.name = "Question"
	_question_label.custom_minimum_size.y = 200
	card.add_child(_question_label)
	_answers = UI.vbox(20)
	_answers.name = "Answers"
	_content.add_child(_answers)
	running = true
	_next_question()


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	_timer_label.text = "%d ث" % ceili(maxf(time_left, 0.0))
	if time_left <= 0.0:
		end_now()


func _next_question() -> void:
	if _pool.is_empty():
		_pool = Content.grade_questions(int(Profiles.current().grade), ["mcq", "tf"], true)
		_pool.shuffle()
	var session := QuizSession.new([_pool.pop_back()], 1)
	_current = session.current()
	_locked = false
	_clear(_answers)
	var rtl := Content.book_lang(str(_current.get("key", "")).split("/")[0]) != "en"
	_answers.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	_question_label.text = str(_current.q)
	if _current.type == "tf":
		var row := UI.hbox(24)
		_answers.add_child(row)
		for value in [true, false]:
			var b := UI.button(("صح" if value else "خطأ") if rtl else ("True" if value else "False"),
				UI.GOOD.darkened(0.1) if value else UI.BAD.darkened(0.05), 50, 160)
			b.name = "True" if value else "False"
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(answer_current.bind(value, b))
			row.add_child(b)
	else:
		for i in _current.choices.size():
			var b := UI.button(str(_current.choices[i]), Color.WHITE, 40, 120, UI.TEXT)
			b.add_theme_stylebox_override("normal", UI.box(Color.WHITE, 32, color.lightened(0.3), 4))
			b.name = "Choice%d" % i
			b.pressed.connect(answer_current.bind(i, b))
			_answers.add_child(b)


## Answers the current question (int choice index or bool), flashes the button and moves on.
func answer_current(value: Variant, button: Button = null) -> void:
	if not running or _locked:
		return
	_locked = true
	var ok := QuizSession.is_correct(_current, value)
	results.append({"key": _current.get("key", ""), "correct": ok})
	_score_label.text = str(correct_count())
	if button:
		UI.style_button(button, UI.GOOD if ok else UI.BAD)
	_play(ok)
	if is_inside_tree():
		await get_tree().create_timer(0.35).timeout
	if running:
		_next_question()


func current_question() -> Dictionary:
	return _current


func correct_count() -> int:
	var n := 0
	for r in results:
		if r.correct:
			n += 1
	return n


func end_now() -> void:
	if not running:
		return
	running = false
	# Wrong answers join the review list like in any round, so they come back later.
	var summary := Profiles.finish_round("speed", "", 0, results)
	_clear(_content)
	_content.add_child(UI.label("خلص الوقت!", 60, color.darkened(0.2)))
	var score := UI.label("%d إجابات صحيحة من %d" % [correct_count(), results.size()], 48, UI.TEXT)
	score.name = "FinalScore"
	_content.add_child(score)
	if summary.new_best:
		_content.add_child(UI.label("رقم قياسي جديد!", 48, Color("#E67E22")))
	else:
		_content.add_child(UI.label("أفضل نتيجة لك: %d" % int(summary.speed_best), 38, UI.MUTED))
	RESULTS_SCRIPT.add_rewards(_content, summary, color)
	var again := UI.button("مرة ثانية", color, 46, 140)
	again.name = "Again"
	again.pressed.connect(func(): main.goto("speed"))
	_content.add_child(again)
	var back := UI.button("رجوع", Color("#95A5A6"), 42, 120)
	back.name = "Back"
	back.pressed.connect(go_back)
	_content.add_child(back)


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _play(ok: bool) -> void:
	var path := "res://assets/sfx/%s.wav" % ("correct" if ok else "wrong")
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.play()
