class_name Screen
extends Control
## Base for full-page screens. main.gd creates one, sets `main` and `args`, then calls build().

var main: Node
var args: Dictionary = {}


func build() -> void:
	pass


## Android back button / Escape. Override to go somewhere other than the profile screen.
func go_back() -> void:
	main.goto("profiles")


## Top bar: a back button and a title. Returns the content box below it, inside a scroll.
func page(title: String, color: Color = UI.TEXT, show_back := true) -> VBoxContainer:
	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bar := UI.hbox(24)
	var bar_margin := UI.margin(bar, 40, 36)
	root.add_child(bar_margin)
	if show_back:
		var back := UI.button("رجوع", color, 36, 100)
		back.custom_minimum_size.x = 200
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(go_back)
		bar.add_child(back)
	var t := UI.label(title, 48, UI.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(t)
	if show_back:
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 200
		bar.add_child(spacer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := UI.vbox(32)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(UI.margin(content, 48, 16))
	scroll.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content
