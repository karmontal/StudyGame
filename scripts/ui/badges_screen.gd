extends Screen
## All badges: earned ones in color, the rest grey with how to earn them.


func build() -> void:
	var p := Profiles.current()
	var owned: Dictionary = Profiles.info().badges
	var content := page("أوسمتي", Color(p.color))
	content.add_child(UI.label("جمعت %d من %d وسام" % [owned.size(), Rewards.BADGES.size()], 40, UI.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	content.add_child(grid)
	for b in Rewards.BADGES:
		var has: bool = owned.has(b.id)
		var card := UI.card(Color.WHITE if has else Color("#F3EFE6"))
		card.name = "Badge_" + b.id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(6)
		card.add_child(v)
		v.add_child(Medal.make(Color(b.color), has, 140))
		v.add_child(UI.label(b.name, 36, Color(b.color).darkened(0.25) if has else UI.MUTED))
		v.add_child(UI.label(b.desc, 28, UI.MUTED))
		grid.add_child(card)


func go_back() -> void:
	main.goto("books")
