extends Screen
## Parents' settings: the dashboard server address and device key, a connection test and sync status.

var _url: LineEdit
var _key: LineEdit
var _status: Label
var _info: Label


func build() -> void:
	var content := page("إعدادات الأهل", UI.TEXT)
	content.add_child(UI.label("اربط اللعبة بلوحة المتابعة على سيرفرك: تنرسل الدروس والنتائج، وتوصل المهام اللي بتضيفها للأولاد.", 32, UI.MUTED))
	content.add_child(UI.label("عنوان السيرفر", 36, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_url = _field("Url", str(Settings.get_value("server_url", "")), "https://study.example.com")
	content.add_child(_url)
	content.add_child(UI.label("مفتاح الجهاز", 36, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_key = _field("Key", str(Settings.get_value("device_key", "")), "STUDYGAME_DEVICE_KEY")
	_key.secret = true
	content.add_child(_key)
	var save := UI.button("حفظ وتجربة الاتصال", Color("#2980B9"), 40, 120)
	save.name = "Save"
	save.pressed.connect(save_and_test)
	content.add_child(save)
	_status = UI.label("", 36, UI.TEXT)
	_status.name = "Status"
	content.add_child(_status)
	var sync := UI.button("زامن الآن", Color("#16A085"), 40, 120)
	sync.name = "SyncNow"
	sync.pressed.connect(func():
		_status.text = "جاري المزامنة..."
		Sync.sync_now())
	content.add_child(sync)
	_info = UI.label("", 30, UI.MUTED)
	_info.name = "Info"
	content.add_child(_info)
	Sync.synced.connect(_on_synced)
	_refresh_info()


func go_back() -> void:
	main.goto("profiles")


func _exit_tree() -> void:
	if Sync.synced.is_connected(_on_synced):
		Sync.synced.disconnect(_on_synced)


func _field(node_name: String, value: String, hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.name = node_name
	e.text = value
	e.placeholder_text = hint
	e.custom_minimum_size.y = 110
	e.add_theme_font_size_override("font_size", 36)
	e.layout_direction = Control.LAYOUT_DIRECTION_LTR
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL if node_name == "Url" else LineEdit.KEYBOARD_TYPE_DEFAULT
	e.add_theme_stylebox_override("normal", UI.box(Color.WHITE, 24, Color("#BDC3C7"), 3))
	e.add_theme_stylebox_override("focus", UI.box(Color.WHITE, 24, Color("#2980B9"), 3))
	return e


func save_and_test() -> void:
	var url := _url.text.strip_edges().trim_suffix("/")
	Settings.set_value("server_url", url)
	Settings.set_value("device_key", _key.text.strip_edges())
	if url == "":
		_status.text = "تم مسح الربط، اللعبة بتشتغل بدون سيرفر"
		return
	if not (url.begins_with("http://") or url.begins_with("https://")):
		_status.text = "العنوان لازم يبدأ بـ https://"
		return
	_status.text = "جاري التجربة..."
	Sync.ping(url, _key.text, func(ok: bool, message: String):
		if not is_inside_tree():
			return
		_status.text = message
		if ok:
			Sync.sync_now())


func _on_synced(_ok: bool, message: String) -> void:
	_status.text = message
	_refresh_info()


func _refresh_info() -> void:
	_info.text = "جولات بانتظار الإرسال: %d\nآخر مزامنة: %s\nرقم الجهاز: %s" % [Sync.events.size(),
		Sync.last_sync if Sync.last_sync != "" else "لسا", Settings.device_id()]
