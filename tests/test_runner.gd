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
	_test_curriculum_index()
	_test_all_books_valid()
	_test_validator_catches_mistakes()
	_test_session_mcq()
	_test_session_tf_match_order()
	_test_stars()
	_test_progress_and_save()
	await _test_ui_flow()
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
