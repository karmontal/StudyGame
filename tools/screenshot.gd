extends Node
## Renders a screen and saves a PNG (needs a display or xvfb, not --headless). Example:
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- quiz out.png nada g3_science
## Screens: profiles, books, map, quiz, feedback, result. Optional: profile id, book id.

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
	var data := Content.book(book_id)
	var u: Dictionary = data.units[0]
	var l: Dictionary = u.lessons[0]
	var key := Profiles.lesson_key(book_id, u.id, l.id)
	Profiles.record_quiz(key, 2, [])
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
			main.goto("result", {"stars": 2, "correct": 6, "total": 8, "quiz_args": {"title": l.title, "lesson_key": key, "back": "map", "back_args": {"book": book_id}}})
	await _frames(60)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	Profiles.delete_save()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
