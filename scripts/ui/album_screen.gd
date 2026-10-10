extends Screen
## Sticker album and shop: stickers the kid owns, and the rest with a price to buy them with coins.

var _coins_label: Label
var _grid: GridContainer
var _message: Label


func build() -> void:
	var p := Profiles.current()
	var content := page("ألبوم الملصقات", Color(p.color))
	var coins := CoinIcon.with_amount(Profiles.coins(), 52)
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	_coins_label = coins.get_node("Amount")
	content.add_child(coins)
	content.add_child(UI.label("اجمع عملات من الأسئلة واشترِ ملصقات لألبومك", 34, UI.MUTED))
	_message = UI.label("", 38, Color(p.color).darkened(0.2))
	_message.name = "Message"
	content.add_child(_message)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 24)
	content.add_child(_grid)
	_fill()


func go_back() -> void:
	main.goto("books")


func _fill() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_coins_label.text = str(Profiles.coins())
	for st in Profiles.sticker_catalog:
		_grid.add_child(_sticker_card(st))


func _sticker_card(st: Dictionary) -> PanelContainer:
	var owned := Profiles.has_sticker(st.id)
	var card := UI.card(Color.WHITE if owned else Color("#F3EFE6"))
	card.name = "Sticker_" + st.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(10)
	card.add_child(v)
	v.add_child(_picture(st, owned))
	v.add_child(UI.label(st.name if owned else "؟؟؟", 34, UI.TEXT if owned else UI.MUTED))
	if not owned:
		var price := int(st.price)
		var can := Profiles.coins() >= price
		var buy := UI.button("اشترِ بـ %d" % price, Color("#F7B500") if can else Color("#BBBBBB"), 34, 100)
		buy.name = "Buy_" + st.id
		buy.disabled = not can
		buy.pressed.connect(_buy.bind(st))
		v.add_child(buy)
	return card


func _picture(st: Dictionary, owned: bool) -> Control:
	var tex: Texture2D = load(st.file) if ResourceLoader.exists(st.file) else null
	if tex == null:
		# Art is downloaded in CI; without it show a letter badge instead.
		var a := Avatar.make(st.name if owned else "؟", Color("#16A085") if owned else Color("#C9C4B8"), 220)
		a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return a
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(0, 280)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		r.modulate = Color(0, 0, 0, 0.25)  # a shadow of the sticker until it is bought
	return r


func _buy(st: Dictionary) -> void:
	var result = Profiles.buy_sticker(st.id)
	if result == null:
		return
	_message.text = "مبروك! صار عندك ملصق %s" % st.name
	for id in result:
		_message.text += "\nووسام جديد: " + Rewards.badge(id).name
	_fill()
