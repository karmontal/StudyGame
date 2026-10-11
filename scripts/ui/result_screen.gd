extends Screen
## End of a round: stars, score, the finished reward, coins and new badges.
## args: stars, correct, total, quiz_args, summary (from Profiles.finish_round).


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
	_add_rewards(content, args.get("summary", {}), color)
	if quiz_args.get("kind", "") != "daily":
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


## Coins earned (with the reasons), level-up and new badges. Shared with the speed challenge.
static func add_rewards(content: VBoxContainer, summary: Dictionary, color: Color) -> void:
	if summary.is_empty():
		return
	var big: bool = int(summary.level_after) > int(summary.level_before) or not summary.new_badges.is_empty()
	Sfx.play("fanfare" if big else ("coin" if int(summary.coins) > 0 else "wrong"))
	if int(summary.level_after) > int(summary.level_before):
		var up := UI.label("مستوى جديد! صرت في المستوى %d · %s" % [summary.level_after, Rewards.level_title(int(summary.level_after))], 44, Color.WHITE)
		up.name = "LevelUp"
		up.add_theme_stylebox_override("normal", UI.box(color, 36))
		content.add_child(up)
	var card := UI.card()
	card.name = "Coins"
	content.add_child(card)
	var v := UI.vbox(8)
	card.add_child(v)
	var total := CoinIcon.with_amount(int(summary.coins), 60, Color("#B07D00"))
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.get_node("Amount").text = "+%d" % int(summary.coins)
	v.add_child(total)
	for line in summary.lines:
		var row := UI.hbox(12)
		var name_l := UI.label(str(line[0]), 32, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var amount := UI.label("+%d" % int(line[1]), 32, UI.TEXT)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(amount)
		v.add_child(row)
	for id in summary.new_badges:
		var b := Rewards.badge(id)
		var row := UI.hbox(20)
		row.name = "NewBadge_" + id
		row.add_child(Medal.make(Color(b.color), true, 120))
		var t := UI.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UI.label("وسام جديد: " + b.name, 40, Color(b.color).darkened(0.25), HORIZONTAL_ALIGNMENT_LEFT))
		t.add_child(UI.label(b.desc, 30, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(t)
		content.add_child(row)


func _add_rewards(content: VBoxContainer, summary: Dictionary, color: Color) -> void:
	add_rewards(content, summary, color)
