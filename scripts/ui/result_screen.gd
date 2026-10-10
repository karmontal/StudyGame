extends Screen
## End of a round: stars, score and the finished reward. args: stars, correct, total, quiz_args.


func build() -> void:
	var p := Profiles.current()
	var color := Color(p.color)
	var quiz_args: Dictionary = args.quiz_args
	var content := page(quiz_args.get("title", ""), color)
	var earned: int = args.stars
	var messages := ["حاول مرة ثانية، بتقدر!", "بداية حلوة!", "شغل ممتاز!", "بطل! كلها صح تقريباً"]
	content.add_child(UI.label(messages[earned], 60, color.darkened(0.2)))
	var stars := StarRow.make(earned, 130)
	stars.name = "Stars"
	content.add_child(stars)
	content.add_child(UI.label("%d من %d إجابات صحيحة" % [args.correct, args.total], 44, UI.TEXT))
	if Profiles.is_young(p):
		var pic := PictureReveal.make(int(args.total), hash(str(quiz_args.get("lesson_key", quiz_args.get("title", "")))))
		pic.custom_minimum_size.y = 560
		content.add_child(pic)
		if earned >= 2:
			pic.reveal_all.call_deferred()
	else:
		content.add_child(UI.label("فتحت القفل!" if earned >= 2 else "القفل لسا مسكّر، جرّب كمان مرة", 44, UI.GOOD.darkened(0.3) if earned >= 2 else UI.MUTED))
	var again := UI.button("العب مرة ثانية", color, 46, 140)
	again.name = "Again"
	again.pressed.connect(func(): main.goto("quiz", quiz_args))
	content.add_child(again)
	var back := UI.button("رجوع", Color("#95A5A6"), 42, 120)
	back.name = "Back"
	back.pressed.connect(go_back)
	content.add_child(back)


func go_back() -> void:
	var quiz_args: Dictionary = args.quiz_args
	main.goto(quiz_args.get("back", "books"), quiz_args.get("back_args", {}))
