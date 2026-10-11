extends Node
## Headless test suite. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 on success, 1 on any failure.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := 0
var _checks := 0


func _ready() -> void:
	Profiles.path = "user://test_save.json"
	Profiles.delete_save()
	Settings.path = "user://test_settings.cfg"
	Settings.reset()
	Sync.path = "user://test_sync.json"
	Sync.reset()
	_test_curriculum_index()
	_test_all_books_valid()
	_test_validator_catches_mistakes()
	_test_session_mcq()
	_test_session_tf_match_order()
	_test_stars()
	_test_progress_and_save()
	_test_reward_rules()
	_test_finish_round()
	await _test_ui_flow()
	await _test_challenges_ui()
	await _test_sound()
	await _test_sync_and_tasks()
	await _test_toddler()
	Profiles.delete_save()
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + label)


func eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _test_curriculum_index() -> void:
	eq(Content.books.size(), 18, "index lists the 18 books")
	for grade in [3, 5, 8, 10]:
		check(Content.books_for_grade(grade).size() >= 4, "grade %d has at least 4 books" % grade)
	for b in Content.books:
		check(Content.subjects.has(b.subject), "%s subject '%s' is defined" % [b.id, b.subject])
		check(FileAccess.file_exists("res://" + b.source), "%s source PDF exists" % b.id)
	for p in Profiles.profiles:
		check(not Content.books_for_grade(int(p.grade)).is_empty(), "%s has books for grade %d" % [p.name, p.grade])


func _test_all_books_valid() -> void:
	var with_data := 0
	for b in Content.books:
		if not Content.has_book_data(b.id):
			continue
		with_data += 1
		var data := Content.book(b.id)
		eq(data.get("id"), b.id, "%s file id matches index" % b.id)
		var errors := Content.validate_book(data)
		for e in errors:
			printerr("  ", e)
		eq(errors.size(), 0, "%s has no data errors" % b.id)
	check(with_data >= 1, "at least one book has questions")


func _test_validator_catches_mistakes() -> void:
	check(not Content.validate_question({"type": "mcq", "q": "x", "choices": ["a", "b"], "answer": 2}, "t").is_empty(), "mcq answer out of range is caught")
	check(not Content.validate_question({"type": "mcq", "q": "x", "choices": ["a", "a"], "answer": 0}, "t").is_empty(), "duplicate choices are caught")
	check(not Content.validate_question({"type": "tf", "q": "x", "answer": "yes"}, "t").is_empty(), "tf with non-bool answer is caught")
	check(not Content.validate_question({"type": "order", "q": "x", "items": ["a", "b"]}, "t").is_empty(), "order with 2 items is caught")
	check(not Content.validate_question({"type": "riddle", "q": "x"}, "t").is_empty(), "unknown type is caught")
	eq(Content.validate_question({"type": "mcq", "q": "x", "choices": ["a", "b", "c"], "answer": 1}, "t").size(), 0, "valid mcq passes")


func _mcq(i: int) -> Dictionary:
	return {"type": "mcq", "q": "q%d" % i, "choices": ["right%d" % i, "w1", "w2", "w3"], "answer": 0, "key": "b/u/l/%d" % i}


func _test_session_mcq() -> void:
	var qs: Array[Dictionary] = []
	for i in 12:
		qs.append(_mcq(i))
	var s := QuizSession.new(qs, 8, 42)
	eq(s.count(), 8, "session caps at 8 questions")
	var keys := {}
	while not s.is_done():
		var q := s.current()
		keys[q.key] = true
		eq(q.choices[q.answer], "right" + str(q.q).substr(1), "shuffled answer index still points at the right choice")
		check(s.answer(int(q.answer)), "right mcq answer accepted")
		s.next()
	eq(keys.size(), 8, "no question repeats in a round")
	eq(s.stars(), 3, "all right gives 3 stars")
	var s2 := QuizSession.new([_mcq(0)] as Array[Dictionary], 8, 1)
	check(not s2.answer((int(s2.current().answer) + 1) % 4), "wrong mcq answer rejected")
	check(not s2.answer("0"), "string answer rejected")


func _test_session_tf_match_order() -> void:
	var tf: Array[Dictionary] = [{"type": "tf", "q": "t", "answer": false, "key": "k"}]
	var s := QuizSession.new(tf, 8, 3)
	check(s.answer(false), "tf false accepted")
	check(not QuizSession.is_correct(s.current(), true), "tf true rejected")
	var m: Array[Dictionary] = [{"type": "match", "q": "m", "pairs": [["a", "1"], ["b", "2"], ["c", "3"], ["d", "4"]], "key": "k"}]
	s = QuizSession.new(m, 8, 7)
	var q := s.current()
	var right_answer: Array = []
	for i in q.left.size():
		right_answer.append(q.right_origin.find(i))
	check(QuizSession.is_correct(q, right_answer), "match with right pairs accepted")
	var wrong := right_answer.duplicate()
	var tmp = wrong[0]
	wrong[0] = wrong[1]
	wrong[1] = tmp
	check(not QuizSession.is_correct(q, wrong), "match with swapped pairs rejected")
	check(not QuizSession.is_correct(q, [0]), "match with missing pairs rejected")
	var o: Array[Dictionary] = [{"type": "order", "q": "o", "items": ["1", "2", "3", "4"], "key": "k"}]
	s = QuizSession.new(o, 8, 9)
	q = s.current()
	check(q.shuffled_origin != [0, 1, 2, 3], "order items start shuffled")
	var taps: Array = []
	for pos in 4:
		taps.append(q.shuffled_origin.find(pos))
	check(QuizSession.is_correct(q, taps), "order tapped correctly accepted")
	taps.reverse()
	check(not QuizSession.is_correct(q, taps), "order reversed rejected")
	check(QuizSession.correct_text(q).contains("1") and QuizSession.correct_text(q).contains("4"), "order correct text lists the items")


func _test_stars() -> void:
	eq(QuizSession.stars_for(8, 8), 3, "8/8 = 3 stars")
	eq(QuizSession.stars_for(6, 8), 2, "6/8 = 2 stars")
	eq(QuizSession.stars_for(4, 8), 1, "4/8 = 1 star")
	eq(QuizSession.stars_for(3, 8), 0, "3/8 = 0 stars")
	eq(QuizSession.stars_for(0, 0), 0, "empty round = 0 stars")


func _test_progress_and_save() -> void:
	eq(Profiles.profiles.size(), 4, "four kids by default")
	Profiles.select("nada")
	check(Profiles.is_young(), "Nada (grade 3) gets the young style")
	check(not Profiles.is_young(Profiles.get_profile("lamees")), "Lamees (grade 10) gets the older style")
	Profiles.record_quiz("b/u/l", 2, [{"key": "b/u/l/0", "correct": true}, {"key": "b/u/l/1", "correct": false}])
	eq(Profiles.stars("b/u/l"), 2, "stars recorded")
	Profiles.record_quiz("b/u/l", 1, [{"key": "b/u/l/1", "correct": false}])
	eq(Profiles.stars("b/u/l"), 2, "stars never go down")
	eq(Profiles.review_keys(), ["b/u/l/1"] as Array[String], "wrong answer joins review")
	Profiles.load_save()
	eq(Profiles.stars("b/u/l", "nada"), 2, "stars survive reload")
	eq(Profiles.stars("b/u/l", "lamees"), 0, "progress is per kid")
	Profiles.select("nada")
	Profiles.record_quiz("", 0, [{"key": "b/u/l/1", "correct": true}])
	eq(Profiles.review_keys().size(), 0, "right answer leaves review")
	Profiles.delete_save()


func _first_book_with_data(grade: int) -> String:
	for b in Content.books_for_grade(grade):
		if Content.has_book_data(b.id):
			return b.id
	return ""


## Clicks through every screen for each kid that has a book with questions: profile → book → map →
## lesson quiz (answering everything right) → result.
func _test_ui_flow() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	for p in Profiles.profiles:
		var book_id := _first_book_with_data(int(p.grade))
		if book_id == "":
			continue
		main.goto("profiles")
		await get_tree().process_frame
		var card: Button = main.find_child("Profile_" + p.id, true, false)
		check(card != null, "profile card for %s" % p.id)
		card.pressed.emit()
		await get_tree().process_frame
		eq(str(main.screen.name), "books", "%s: profile opens books" % p.id)
		var book_btn: Button = main.find_child("Book_" + book_id, true, false)
		check(book_btn != null and not book_btn.disabled, "%s: book %s is open" % [p.id, book_id])
		book_btn.pressed.emit()
		await get_tree().process_frame
		eq(str(main.screen.name), "map", "%s: book opens map" % p.id)
		var data := Content.book(book_id)
		var lesson_btn: Button = null
		var key := ""
		for u in data.units:
			for l in u.lessons:
				if not l.get("questions", []).is_empty() and lesson_btn == null:
					lesson_btn = main.find_child("Lesson_%s_%s" % [u.id, l.id], true, false)
					key = Profiles.lesson_key(book_id, u.id, l.id)
		check(lesson_btn != null, "%s: a lesson with questions is on the map" % p.id)
		lesson_btn.pressed.emit()
		await get_tree().process_frame
		eq(str(main.screen.name), "quiz", "%s: lesson opens quiz" % p.id)
		var quiz = main.screen
		check(quiz.reward is PictureReveal if Profiles.is_young(p) else quiz.reward is LockPanel, "%s: right reward style" % p.id)
		var guard := 0
		while str(main.screen.name) == "quiz" and guard < 20:
			guard += 1
			await _answer_right(main.screen)
			var next: Button = main.screen.find_child("Next", true, false)
			check(next != null, "%s: next button after answering" % p.id)
			next.pressed.emit()
			await get_tree().process_frame
		eq(str(main.screen.name), "result", "%s: quiz ends on result" % p.id)
		eq(main.screen.args.stars, 3, "%s: all right answers give 3 stars" % p.id)
		eq(Profiles.stars(key, p.id), 3, "%s: stars saved for the lesson" % p.id)
		main.screen.go_back()
		await get_tree().process_frame
		eq(str(main.screen.name), "map", "%s: result goes back to map" % p.id)
	main.queue_free()
	Profiles.delete_save()


func _results(pattern: String) -> Array:
	var out := []
	for c in pattern:
		out.append({"key": "", "correct": c == "1"})
	return out


func _test_reward_rules() -> void:
	# 8 right: 80 for answers, combo bonus from the 3rd on (6 x 5), 3 stars x 5, perfect 20.
	var pay := Rewards.round_coins(_results("11111111"), 3)
	eq(pay.total, 80 + 30 + 15 + 20, "coins for a perfect round")
	pay = Rewards.round_coins(_results("11011100"), 1)
	eq(pay.total, 50 + 5 + 5, "coins for a mixed round (combo resets on a wrong answer)")
	eq(Rewards.round_coins(_results("111"), 0, "speed").total, 30 + 5, "speed rounds get no star or perfect bonus")
	eq(Rewards.round_coins(_results("10"), 0, "daily").total, 10 + Rewards.DAILY_BONUS, "daily bonus")
	eq(Rewards.best_combo(_results("1101110")), 3, "best combo")
	eq(Rewards.level_for(0), 1, "level 1 at 0 xp")
	eq(Rewards.level_for(Rewards.XP_PER_LEVEL - 1), 1, "still level 1 just below the threshold")
	eq(Rewards.level_for(Rewards.XP_PER_LEVEL), 2, "level 2 at the threshold")
	eq(Rewards.streak_bonus(2), 20, "streak bonus grows per day")
	eq(Rewards.streak_bonus(30), Rewards.STREAK_BONUS_MAX, "streak bonus is capped")
	for b in Rewards.BADGES:
		check(Rewards.badge(b.id).name != "", "badge %s has a name" % b.id)


func _test_finish_round() -> void:
	Profiles.delete_save()
	Profiles.select("lamees")
	Profiles.today_override = "2026-10-12"  # a Monday
	var s := Profiles.finish_round("lesson", "g10_chemistry/u1/l1", 3, _results("11111111"))
	var badges: Array = s.new_badges
	check(badges.has("first_round") and badges.has("perfect") and badges.has("combo5"), "first perfect round earns its badges")
	eq(s.coins, 145 + 10 + 3 * Profiles.BADGE_COINS, "round + day-1 streak + badge coins")
	eq(Profiles.coins(), s.coins, "coins added to the balance")
	eq(s.streak, 1, "streak starts at 1")
	eq(Profiles.stars("g10_chemistry/u1/l1"), 3, "finish_round still records stars")
	s = Profiles.finish_round("lesson", "g10_chemistry/u1/l1", 1, _results("10100000"))
	eq(s.streak, 1, "a second round the same day keeps the streak")
	check(not s.lines.any(func(l): return l[0] == "أيام متتالية"), "streak bonus only on the first round of the day")
	Profiles.today_override = "2026-10-13"
	eq(Profiles.finish_round("review", "", 0, _results("1")).streak, 2, "next day extends the streak")
	Profiles.today_override = "2026-10-14"
	eq(Profiles.live_streak(), 2, "streak still shows the day after")
	Profiles.today_override = "2026-10-16"
	eq(Profiles.live_streak(), 0, "missing a day breaks the streak")
	eq(Profiles.finish_round("review", "", 0, _results("1")).streak, 1, "streak restarts after a missed day")
	check(not Profiles.daily_done(), "daily challenge not done yet")
	s = Profiles.finish_round("daily", "", 3, _results("111111"))
	check(Profiles.daily_done(), "daily challenge done today")
	check(s.new_badges.has("daily1"), "daily badge")
	eq(Profiles.stars("daily/2026-10-16"), 0, "daily rounds don't store lesson stars")
	s = Profiles.finish_round("speed", "", 0, _results("111111111111"))
	check(s.new_best and s.speed_best == 12, "speed best saved")
	check(s.new_badges.has("speed10"), "speed badge")
	check(not Profiles.finish_round("speed", "", 0, _results("11")).new_best, "lower speed score is not a record")
	check(Profiles.week_coins("lamees") > 0, "coins count for this week")
	eq(Profiles.week_coins("nada"), 0, "other kids start the week at 0")
	Profiles.today_override = "2026-10-19"  # next Monday
	eq(Profiles.week_coins("lamees"), 0, "weekly board resets on Monday")
	# Stickers
	var st: Dictionary = Profiles.sticker_catalog[0]
	Profiles.info().coins = int(st.price) - 1
	eq(Profiles.buy_sticker(st.id), null, "can't buy without enough coins")
	Profiles.info().coins = int(st.price) + 5
	check(Profiles.buy_sticker(st.id) != null, "buy a sticker")
	eq(Profiles.coins(), 5, "sticker price taken from coins")
	check(Profiles.has_sticker(st.id), "sticker owned")
	eq(Profiles.buy_sticker(st.id), null, "can't buy the same sticker twice")
	# Everything survives a reload, including old saves without the new fields.
	var xp := int(Profiles.info().xp)
	Profiles.load_save()
	eq(int(Profiles.info("lamees").xp), xp, "xp saved")
	check(Profiles.info("lamees").stickers.has(st.id), "stickers saved")
	eq(int(Profiles.info("lamees").streak.days), 1, "streak saved")
	Profiles.progress["mufeed"] = {"stars": {}, "review": {}, "answered": 3, "correct": 2}
	eq(Profiles.coins("mufeed"), 0, "old save gets default coins")
	eq(Profiles.info("mufeed").streak.last, "", "old save gets an empty streak")
	Profiles.today_override = ""
	Profiles.delete_save()


func _test_challenges_ui() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	for p in Profiles.profiles:
		if Content.grade_questions(int(p.grade)).is_empty():
			continue
		Profiles.select(p.id)
		main.goto("books")
		await get_tree().process_frame
		check(main.find_child("Status", true, false) != null, "%s: status card on books screen" % p.id)
		var daily: Button = main.find_child("Daily", true, false)
		check(daily != null and daily.disabled, "%s: daily locked before any lesson is finished" % p.id)
		check((main.find_child("Speed", true, false) as Button).disabled, "%s: speed locked before any lesson" % p.id)
		# Finish one lesson with a single star: challenges open and only use that lesson.
		var first: Dictionary = Content.grade_questions(int(p.grade), ["mcq", "tf"])[0]
		var parts: PackedStringArray = str(first.key).split("/")
		var done_key := "/".join([parts[0], parts[1], parts[2]])
		Profiles.record_quiz(done_key, 1, [])
		for q in Content.daily_questions(int(p.grade), Profiles.today(), p.id):
			check(str(q.key).begins_with(done_key + "/"), "%s: daily question from a finished lesson" % p.id)
		main.goto("books")
		await get_tree().process_frame
		daily = main.find_child("Daily", true, false)
		check(daily != null and not daily.disabled, "%s: daily challenge open" % p.id)
		daily.pressed.emit()
		await get_tree().process_frame
		eq(str(main.screen.name), "quiz", "%s: daily opens a quiz" % p.id)
		var guard := 0
		while str(main.screen.name) == "quiz" and guard < 20:
			guard += 1
			await _answer_right(main.screen)
			(main.screen.find_child("Next", true, false) as Button).pressed.emit()
			await get_tree().process_frame
		eq(str(main.screen.name), "result", "%s: daily ends on result" % p.id)
		check(main.screen.find_child("Coins", true, false) != null, "%s: result shows coins" % p.id)
		check(main.screen.find_child("Again", true, false) == null, "%s: daily can't be replayed for coins" % p.id)
		main.screen.go_back()
		await get_tree().process_frame
		check((main.find_child("Daily", true, false) as Button).disabled, "%s: daily done for today" % p.id)
		# Whole-unit test opens only after every lesson of the unit has a star.
		var ub: String = parts[0]
		var uid: String = parts[1]
		var playable := 0
		for l in Content.unit(ub, uid).lessons:
			if not Content.lesson_questions(ub, uid, l.id).is_empty():
				playable += 1
		if Content.unit_questions(ub, uid).size() >= 4:
			main.goto("map", {"book": ub})
			await get_tree().process_frame
			var ut: Button = main.find_child("UnitTest_" + uid, true, false)
			eq(ut.disabled, playable > 1, "%s: unit test locked until all lessons are done" % p.id)
			for l in Content.unit(ub, uid).lessons:
				if not Content.lesson_questions(ub, uid, l.id).is_empty():
					Profiles.record_quiz(Profiles.lesson_key(ub, uid, l.id), 1, [])
			main.goto("map", {"book": ub})
			await get_tree().process_frame
			check(not (main.find_child("UnitTest_" + uid, true, false) as Button).disabled, "%s: unit test opens" % p.id)
			main.goto("books")
			await get_tree().process_frame
		# Speed challenge
		(main.find_child("Speed", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		eq(str(main.screen.name), "speed", "%s: speed screen opens" % p.id)
		var speed = main.screen
		(speed.find_child("Start", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		check(str(speed.current_question().key).begins_with(parts[0] + "/" + parts[1] + "/"), "%s: speed uses finished lessons" % p.id)
		for i in 3:
			var q: Dictionary = speed.current_question()
			speed.answer_current(int(q.answer) if q.type == "mcq" else q.answer)
			await get_tree().create_timer(0.45).timeout
		eq(speed.correct_count(), 3, "%s: speed answers counted" % p.id)
		speed.end_now()
		await get_tree().process_frame
		check(speed.find_child("FinalScore", true, false) != null, "%s: speed final score" % p.id)
		eq(int(Profiles.info().speed_best), 3, "%s: speed best saved" % p.id)
		# Badges and album
		main.goto("badges")
		await get_tree().process_frame
		check(main.find_child("Badge_first_round", true, false) != null, "%s: badges screen lists badges" % p.id)
		main.goto("album")
		await get_tree().process_frame
		var st: Dictionary = Profiles.sticker_catalog[1]
		Profiles.info().coins = int(st.price)
		main.goto("album")
		await get_tree().process_frame
		var buy: Button = main.find_child("Buy_" + st.id, true, false)
		check(buy != null and not buy.disabled, "%s: can afford a sticker" % p.id)
		buy.pressed.emit()
		await get_tree().process_frame
		check(Profiles.has_sticker(st.id), "%s: sticker bought from the album" % p.id)
		check(main.find_child("Buy_" + st.id, true, false) == null, "%s: bought sticker has no buy button" % p.id)
	main.goto("profiles")
	await get_tree().process_frame
	check(main.find_child("Leader", true, false) != null, "weekly leader shown on the profile screen")
	main.queue_free()
	Profiles.delete_save()


func _answer_right(quiz: Node) -> void:
	var q: Dictionary = quiz.session.current()
	match q.type:
		"mcq":
			(quiz.find_child("Choice%d" % int(q.answer), true, false) as Button).pressed.emit()
		"tf":
			(quiz.find_child("True" if q.answer else "False", true, false) as Button).pressed.emit()
		"match":
			for i in q.left.size():
				(quiz.find_child("Left%d" % i, true, false) as Button).pressed.emit()
				(quiz.find_child("Right%d" % q.right_origin.find(i), true, false) as Button).pressed.emit()
			var check_btn: Button = quiz.find_child("Check", true, false)
			check(not check_btn.disabled, "match check enabled once all paired")
			check_btn.pressed.emit()
		"order":
			for pos in q.items.size():
				(quiz.find_child("Item%d" % q.shuffled_origin.find(pos), true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(quiz.session.results.back().correct, "answered %s question right through the UI" % q.type)


func _test_sound() -> void:
	for n in Sfx.NAMES:
		check(ResourceLoader.exists("res://assets/sfx/%s.wav" % n), "sound %s exists" % n)
	var mcq := {"type": "mcq", "q": "كم رجل للعنكبوت؟", "choices": ["6", "8"], "answer": 1}
	var said := Sfx.question_text(mcq, "ar")
	check(said.begins_with("كم رجل") and "الخيار الأول: 6" in said and "الخيار الثاني: 8" in said, "read-aloud has question and choices")
	check("True or false?" in Sfx.question_text({"type": "tf", "q": "Fish swim", "answer": true}, "en"), "read-aloud tf in English")
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	for p in Profiles.profiles:
		var book_id := _first_book_with_data(int(p.grade))
		if book_id == "":
			continue
		Profiles.select(p.id)
		main.goto("quiz", {"questions": Content.grade_questions(int(p.grade), ["mcq"]).slice(0, 3), "title": "t", "back": "books", "back_args": {}})
		await get_tree().process_frame
		var speak: Button = main.find_child("Speak", true, false)
		eq(speak != null, Profiles.is_young(p), "%s: speaker button only for young kids" % p.id)
		if speak:
			speak.pressed.emit()
			check(Sfx.last_spoken.begins_with(str(main.screen.session.current().q)), "%s: speaker reads the question" % p.id)
			check(main.screen.find_child("SpeakHint", true, false).visible, "%s: no voice in headless shows a hint" % p.id)
		Sfx.last_played = ""
		(main.screen.find_child("Choice0", true, false) as Button).pressed.emit()
		check(Sfx.last_played in ["correct", "wrong"], "%s: answer plays a sound" % p.id)
	main.goto("profiles")
	await get_tree().process_frame
	check(Settings.sound_on(), "sound is on by default")
	(main.find_child("Sound", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(not Settings.sound_on(), "sound switch turns it off")
	(main.find_child("Sound", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(Settings.sound_on(), "sound switch turns it back on")
	main.queue_free()
	await get_tree().process_frame
	Settings.reset()


func _test_sync_and_tasks() -> void:
	Profiles.delete_save()
	Sync.reset()
	check(not Sync.configured(), "sync is off until the parent sets a server")
	var nada := "nada"
	Profiles.select(nada)
	var book_id := _first_book_with_data(3)
	var u: Dictionary = Content.book(book_id).units[0]
	var l: Dictionary = u.lessons[0]
	var key := Profiles.lesson_key(book_id, u.id, l.id)
	var qs := Content.lesson_questions(book_id, u.id, l.id)
	Profiles.finish_round("lesson", key, 2, [{"key": qs[0].key, "correct": true}, {"key": qs[1].key, "correct": false}], book_id, u.id)
	eq(Sync.events.size(), 1, "a finished round is queued for the dashboard")
	var e: Dictionary = Sync.events[0]
	eq(e.kind, "lesson", "event kind")
	eq(e.lesson_key, key, "event lesson key")
	eq(e.title, l.title, "event has the lesson title")
	eq([e.correct, e.total, e.stars], [1, 2, 2], "event counts")
	eq(e.wrong, [qs[1].key], "event lists wrong questions")
	check(RegEx.create_from_string("^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\d$").search(e.at) != null, "event time format")
	var body := Sync.build_body()
	eq(body.profiles.size(), Profiles.profiles.size(), "sync body has every kid")
	eq(int(body.summary[nada].stars[key]), 2, "sync summary has stars")
	check(str(body.device).begins_with("dev-"), "sync body has a device id")
	# The server answers with an assignment for Nada.
	Sync.apply_response({"ok": true, "assignments": [{"id": "a1", "profile": nada, "title": "اختبار بابا",
		"note": "", "reward": "آيس كريم", "lesson_keys": [key], "count": 4, "min_stars": 2,
		"created_at": "2026-10-11T09:00:00", "done_at": null, "best_stars": 0}]}, [e.id])
	eq(Sync.events.size(), 0, "sent rounds leave the queue")
	eq(Sync.assignments_for("lamees").size(), 0, "assignments are per kid")
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.goto("books")
	await get_tree().process_frame
	var task: Button = main.find_child("Task_a1", true, false)
	check(task != null and not task.disabled, "task from dad shows on the books screen")
	task.pressed.emit()
	await get_tree().process_frame
	eq(str(main.screen.name), "quiz", "task opens a quiz")
	eq(main.screen.session.count(), 4, "task uses its question count")
	var guard := 0
	while str(main.screen.name) == "quiz" and guard < 10:
		guard += 1
		await _answer_right(main.screen)
		(main.screen.find_child("Next", true, false) as Button).pressed.emit()
		await get_tree().process_frame
	check(main.screen.find_child("TaskResult", true, false) != null, "result says the task is passed")
	check(Sync.assignment_by_id("a1").done_at != null, "task marked done on the phone")
	eq(Sync.events[-1].kind, "assignment", "task round queued as an assignment")
	eq(Sync.events[-1].assignment, "a1", "task round carries the assignment id")
	main.goto("books")
	await get_tree().process_frame
	check((main.find_child("Task_a1", true, false) as Button).disabled, "a finished task can't be replayed")
	# Parents' settings screen
	main.goto("parents")
	await get_tree().process_frame
	(main.screen.find_child("Url", true, false) as LineEdit).text = "study.example.com"
	main.screen.save_and_test()
	check("https" in (main.screen.find_child("Status", true, false) as Label).text, "parents screen rejects an address without https")
	(main.screen.find_child("Url", true, false) as LineEdit).text = ""
	main.screen.save_and_test()
	check(not Sync.configured(), "clearing the address turns sync off")
	main.queue_free()
	await get_tree().process_frame
	Sync.reset()
	Settings.reset()


func _frames(n: int = 1) -> void:
	for i in n:
		await get_tree().process_frame


func _test_toddler() -> void:
	Settings.reset()
	ToddlerScreen.play_seconds = 0.0
	# Phrases: short ascii keys for recorded clips, one for every colour, shape, animal and picture.
	var key_re := RegEx.create_from_string("^[a-z0-9_]+$")
	for k in ToddlerVoice.PHRASES:
		check(key_re.search(k) != null, "voice key '%s' is a short ascii id" % k)
	for c in ToddlerArt.COLORS:
		check(ToddlerVoice.PHRASES.has("c_" + c.id), "phrase for colour %s" % c.id)
	for a in ToddlerArt.ANIMALS:
		check(ToddlerVoice.PHRASES.has("a_" + a), "phrase for animal %s" % a)
	for sh in ToddlerArt.SHAPES:
		check(ToddlerVoice.PHRASES.has("s_" + sh), "phrase for shape %s" % sh)
	for id in ToddlerArt.COLORING + ToddlerArt.PUZZLES:
		check(ToddlerVoice.PHRASES.has("p_" + id), "phrase for picture %s" % id)
	check(not ToddlerVoice.has_clip("hello"), "no recorded clip: falls back to the phone voice")
	ToddlerVoice.say("bravo")
	check(ToddlerVoice.last_text == "برافو آية!" and not ToddlerVoice.last_was_clip, "say() uses the phrase text")
	# Pictures: 3-6 fill regions for colouring, and every region can be hit.
	for id in ToddlerArt.COLORING:
		var n: int = ToddlerArt.picture(id).regions.size()
		check(n >= 3 and n <= 6, "colouring picture %s has 3-6 regions (%d)" % [id, n])
	for id in ToddlerArt.COLORING + ToddlerArt.ANIMALS + ToddlerArt.PUZZLES:
		var pic := ToddlerArt.picture(id)
		for i in pic.regions.size():
			eq(ToddlerArt.region_at(pic, ToddlerArt.region_point(pic, i)), i, "%s region %d can be tapped" % [id, i])
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _frames()
	# Hub
	main.goto("toddler")
	await _frames()
	eq(str(main.screen.name), "toddler", "toddler hub opens")
	eq(ToddlerVoice.last_key, "hello", "hub greets Aya")
	for g in ["color", "sort", "shapes", "animals", "balloons"]:
		var b: Control = main.screen.find_child("Game_" + g, true, false)
		check(b is ToddlerButton and b.size.x >= 200 and b.size.y >= 200, "hub has a big %s button" % g)
	# The exit needs a 1.5 s press: a tap, a short press and the Android back do nothing.
	var exit: ToddlerHold = main.screen.find_child("Exit", true, false)
	var mid := exit.size / 2.0
	exit.send_tap(mid)
	exit._process(2.0)
	exit._send(mid, true, false)
	exit._process(1.0)
	exit._send(mid, false, false)
	exit._process(1.0)
	main.screen.go_back()
	eq(str(main.screen.name), "toddler", "short presses and back don't leave the hub")
	exit._send(mid, true, false)
	exit._process(1.0)
	eq(str(main.screen.name), "toddler", "still on the hub after 1 s")
	exit._process(0.6)
	eq(str(main.screen.name), "profiles", "1.5 s press leaves to the profiles")
	await _frames()
	main.goto("toddler")
	await _frames()
	(main.screen.find_child("Game_color", true, false) as Button).pressed.emit()
	await _frames()
	# Colouring
	eq(str(main.screen.name), "toddler_color", "colour button opens colouring")
	var col = main.screen
	(col.find_child("Color_blue", true, false) as Button).pressed.emit()
	eq(ToddlerVoice.last_text, "أزرق", "picking a colour says its name")
	var blue: Color = ToddlerArt.color_by_id("blue").color
	col.canvas.send_tap(col.region_point(2))
	eq(col.current_fills()[2], blue, "tapping a region fills it")
	eq(col.current_fills()[0], Color.WHITE, "other regions stay white")
	eq(Sfx.last_played, "pop", "filling makes a sound")
	col.canvas.send_tap(col.region_point(0), true)
	eq(col.current_fills()[0], blue, "a touch with no new pick uses the last colour")
	(col.find_child("Next", true, false) as Button).pressed.emit()
	eq(col.picture_id(), "apple", "arrow changes picture")
	(col.find_child("Prev", true, false) as Button).pressed.emit()
	eq(col.current_fills()[2], blue, "a picture keeps its colours")
	(col.find_child("Mode", true, false) as Button).pressed.emit()
	check(col.drawing, "brush button switches to free drawing")
	col.canvas.send_drag(Vector2(100, 100), Vector2(600, 400), true)
	check(col.strokes.size() == 1 and col.strokes[0].points.size() >= 4, "finger paints a stroke")
	var twin := InputEventScreenTouch.new()
	twin.device = InputEvent.DEVICE_ID_EMULATION
	twin.pressed = true
	twin.position = Vector2(300, 300)
	col.canvas._gui_input(twin)
	eq(col.strokes.size(), 1, "emulated twin events are ignored")
	(col.find_child("Next", true, false) as Button).pressed.emit()
	eq(col.strokes.size(), 0, "arrow gives a clean page while drawing")
	col.go_back()
	await _frames()
	eq(str(main.screen.name), "toddler", "a game goes back to the hub")
	# Sorting
	main.goto("toddler_sort")
	await _frames()
	var sort = main.screen
	eq(sort.baskets.size(), 2, "sorting starts with 2 baskets")
	eq(sort.balls.size(), 4, "2 balls per basket")
	eq([sort.basket_count(1), sort.basket_count(2), sort.basket_count(4)], [2, 3, 4], "more baskets after a few rounds")
	var ball: Dictionary = sort.balls[0]
	var right: int = sort.basket_index(ball.color_id)
	var wrong: int = 1 - right
	sort.board.send_drag(ball.pos, (sort.baskets[wrong].rect as Rect2).get_center() - Vector2(0, 80))
	check(not ball.placed, "wrong basket doesn't take the ball")
	eq(ball.target, ball.home, "the ball floats back home")
	check(Sfx.last_played != "wrong", "no error sound")
	sort.board.send_drag(ball.pos, (sort.baskets[right].rect as Rect2).get_center() - Vector2(0, 80), true)
	check(ball.placed, "right basket takes the ball (touch drag)")
	eq(ToddlerVoice.last_key, "c_" + ball.color_id, "ball in place says its colour")
	eq(Sfx.last_played, "correct", "cheerful sound for a ball in place")
	for b in sort.balls.duplicate():
		if not b.placed:
			sort.board.send_drag(b.pos, (sort.baskets[sort.basket_index(b.color_id)].rect as Rect2).get_center() - Vector2(0, 80))
	eq(sort.placed_count(), 4, "all balls sorted")
	check(sort.celebrating and sort.board.effect_count() > 30, "confetti when the round is done")
	eq(ToddlerVoice.last_key, "bravo", "round done says bravo")
	eq(sort.round_number, 1, "next round counted")
	# Shapes
	main.goto("toddler_shapes")
	await _frames()
	var sh = main.screen
	eq(sh.stage_kind(), "holes", "shapes start with the hole board")
	eq(sh.holes.size(), 3, "three holes first")
	var pc: Dictionary = sh.pieces[0]
	var other: Dictionary = sh.holes.filter(func(h): return h.kind != pc.kind)[0]
	sh.board.send_drag(pc.pos, other.pos)
	check(not pc.placed and pc.target == pc.home, "a piece doesn't go in the wrong hole")
	sh.board.send_drag(pc.pos, sh.snap_point(pc) + Vector2(40, 30))
	check(pc.placed and pc.target == sh.snap_point(pc), "a piece snaps into its hole when close")
	eq(ToddlerVoice.last_key, "s_" + pc.kind, "the shape says its name")
	for p in sh.pieces.duplicate():
		if not p.placed:
			sh.board.send_drag(p.pos, sh.snap_point(p))
	check(sh.celebrating, "board done: celebration")
	sh.next_stage()
	eq(sh.stage_kind(), "puzzle", "then a picture puzzle")
	eq(sh.pieces.size(), 2, "first puzzle has 2 pieces")
	for p in sh.pieces.duplicate():
		sh.board.send_drag(p.pos + Vector2(40, 40), p.slot + Vector2(70, 50))
		check(p.placed, "puzzle piece snaps into the frame")
	check(sh.celebrating, "puzzle done: celebration")
	eq(ToddlerVoice.last_key, "p_" + sh.picture_id, "finished puzzle says the picture's name")
	# Tap and hear
	main.goto("toddler_animals")
	await _frames()
	for a in ToddlerArt.ANIMALS:
		var ab: Control = main.screen.find_child("Animal_" + a, true, false)
		check(ab != null and ab.size.x >= 200 and ab.size.y >= 200, "big %s button" % a)
	var cow: ToddlerButton = main.screen.find_child("Animal_cow", true, false)
	cow.button_down.emit()
	cow.pressed.emit()
	eq(ToddlerVoice.last_text, "بقرة! مووو", "the cow says its name and moo")
	eq(Sfx.last_played, "boing", "tap plays a sound")
	check(cow._bounce > 0.0, "the cow bounces")
	# Balloons
	main.goto("toddler_balloons")
	await _frames()
	var bal = main.screen
	bal.balloons.clear()
	var bl: Dictionary = bal.spawn(2, Vector2(540, 900))
	bal.board.send_tap(bal.balloon_pos(bl), true)
	eq(bal.popped, 1, "tapping a balloon pops it")
	eq(bal.balloons.size(), 0, "popped balloon is gone")
	eq(Sfx.last_played, "pop", "pop sound")
	eq(ToddlerVoice.last_key, "c_blue", "popped balloon says its colour")
	bal.board.send_tap(Vector2(540, 900))
	eq(bal.popped, 1, "tapping the sky pops nothing (and loses nothing)")
	# Ten minutes of play: time to rest; a parent's long press continues.
	ToddlerScreen.play_seconds = ToddlerScreen.PLAY_LIMIT - 0.001
	await _frames(3)
	eq(str(main.screen.name), "toddler_rest", "rest screen after 10 minutes")
	eq(ToddlerVoice.last_key, "rest", "rest screen says let's rest")
	main.screen.go_back()
	main.screen._process(5.0)
	eq(str(main.screen.name), "toddler_rest", "rest screen stays until a parent continues")
	var cont: ToddlerHold = main.screen.find_child("Continue", true, false)
	cont._send(cont.size / 2.0, true, false)
	cont._process(1.6)
	eq(str(main.screen.name), "toddler", "long press continues to the hub")
	check(ToddlerScreen.play_seconds < 1.0, "play time starts again")
	main.queue_free()
	await _frames()
	ToddlerScreen.play_seconds = 0.0
	Settings.reset()
