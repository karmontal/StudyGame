extends Node
## Renders a screen and saves a PNG (needs a display or xvfb, not --headless). Example:
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- quiz out.png nada g3_science
## Screens: profiles, books, map, quiz, feedback, result, speed, speed_end, badges, album,
## toddler, toddler_color, toddler_color_filled, toddler_draw, toddler_sort, toddler_sort_round3,
## toddler_shapes, toddler_shapes_stage5, toddler_puzzle, toddler_puzzle4, toddler_animals,
## toddler_balloons, toddler_rest, family, family_turn, family_question, family_aya, family_results.
## Optional: profile id, book id.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "profiles"
	var out: String = args[1] if args.size() > 1 else "user://screenshot.png"
	var profile: String = args[2] if args.size() > 2 else "nada"
	var book_id: String = args[3] if args.size() > 3 else "g3_science"
	get_window().size = Vector2i(1080, 1920)
	Profiles.path = "user://screenshot_save.json"
	Profiles.delete_save()
	Profiles.select(profile)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	if which.begins_with("toddler"):
		await _toddler(main, which)
		await _frames(60)
		_save(out)
		return
	var data := Content.book(book_id)
	var u: Dictionary = data.units[0]
	var l: Dictionary = u.lessons[0]
	var key := Profiles.lesson_key(book_id, u.id, l.id)
	Profiles.record_quiz(key, 2, [])
	var all_right := []
	for i in 8:
		all_right.append({"key": "", "correct": true})
	var summary := Profiles.finish_round("lesson", key, 3, all_right, book_id, u.id)
	Profiles.info().coins = 260
	var qs := Content.lesson_questions(book_id, u.id, l.id)
	match which:
		"books":
			main.goto("books")
		"map":
			main.goto("map", {"book": book_id})
		"quiz", "feedback":
			var type: String = args[4] if args.size() > 4 else ""
			if type != "":
				qs = qs.filter(func(q): return q.type == type)
			main.goto("quiz", {"questions": qs, "title": l.title, "lesson_key": key, "book": book_id, "back": "map", "back_args": {"book": book_id}})
			await _frames(5)
			main.screen._submit(-1 if type in ["", "mcq"] else (false if type == "tf" else []))
			if which == "quiz":
				main.screen._next()
		"result":
			main.goto("result", {"stars": 3, "correct": 8, "total": 8, "summary": summary, "quiz_args": {"title": l.title, "lesson_key": key, "back": "map", "back_args": {"book": book_id}}})
		"speed", "speed_end":
			main.goto("speed")
			await _frames(3)
			main.screen.start()
			if which == "speed_end":
				main.screen.answer_current(int(main.screen.current_question().get("answer", 0)) if main.screen.current_question().type == "mcq" else main.screen.current_question().answer)
				await get_tree().create_timer(0.5).timeout
				main.screen.end_now()
		"profiles", "badges", "album":
			main.goto(which)
		"family":
			main.goto("family", {"teams": true})
		"family_turn", "family_question", "family_aya", "family_results":
			var ids := ["lamees", "mufeed", "lujain", "nada", "aya"]
			main.goto("family_play", {"players": ids, "teams": false, "rounds": 1, "rng_seed": 7})
			await _frames(3)
			var s = main.screen
			var stop: int = {"family_turn": 2, "family_question": 2, "family_aya": 4, "family_results": 5}[which]
			for i in stop:
				s.show_question()
				if s.question.type == "picture":
					s.tap_picture(int(s.question.answer))
				else:
					s.submit(s.question.answer if i % 2 == 0 else -1)
				s._show_handoff()
			if which in ["family_question", "family_aya"]:
				s.show_question()
	await _frames(60)
	_save(out)


func _save(out: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	Profiles.delete_save()
	get_tree().quit()


## The toddler screens, with a little play already done so the picture shows something.
func _toddler(main: Node, which: String) -> void:
	ToddlerScreen.play_seconds = 0.0
	match which:
		"toddler_color_filled":
			main.goto("toddler_color")
			await _frames(3)
			var s = main.screen
			s.change_picture(1)  # apple
			s.change_picture(1)  # fish
			var ids := ["orange", "red", "blue", "yellow", "pink", "green"]
			for i in ids.size():
				s.pick(ids[i])
				s.canvas.send_tap(s.region_point(i))
			s.pick("blue")
		"toddler_draw":
			main.goto("toddler_color")
			await _frames(3)
			var s = main.screen
			s.set_drawing(true)
			var ids := ["red", "blue", "green", "yellow"]
			for k in ids.size():
				s.pick(ids[k])
				var pts := []
				for i in 24:
					pts.append(Vector2(120 + i * 28, 180 + k * 170 + sin(i * 0.5 + k) * 70))
				s.canvas._send(pts[0], true, false)
				for i in range(1, pts.size()):
					var m := InputEventMouseMotion.new()
					m.position = pts[i]
					s.canvas._gui_input(m)
				s.canvas._send(pts[-1], false, false)
		"toddler_sort_round3":
			main.goto("toddler_sort")
			await _frames(3)
			main.screen.round_number = 4
			main.screen.new_round()
			var s = main.screen
			var b: Dictionary = s.balls[0]
			var target: Rect2 = s.baskets[s.basket_index(b.color_id)].rect
			s.board.send_drag(b.pos, target.get_center() - Vector2(0, 60))
		"toddler_shapes_stage5", "toddler_puzzle", "toddler_puzzle4":
			main.goto("toddler_shapes")
			await _frames(3)
			main.screen.start_stage({"toddler_shapes_stage5": 4, "toddler_puzzle": 1, "toddler_puzzle4": 5}[which])
			var s = main.screen
			var pc: Dictionary = s.pieces[0]
			s.board.send_drag(pc.pos + Vector2(20, 20), s.snap_point(pc) + Vector2(20, 20))
		_:
			main.goto(which)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
