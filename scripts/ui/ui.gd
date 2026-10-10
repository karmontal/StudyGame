class_name UI
extends RefCounted
## Small factory for the game's look: colors, labels, rounded buttons and cards. Screens build
## their nodes in code with these helpers.

const BG := Color("#FBF3E0")
const TEXT := Color("#2D3047")
const MUTED := Color("#7A7D8C")
const CARD := Color("#FFFFFF")
const GOOD := Color("#2ECC71")
const BAD := Color("#E74C3C")
const STAR := Color("#F7B500")
const STAR_OFF := Color("#D9D4C7")
const PAIR_COLORS := [Color("#3498DB"), Color("#9B59B6"), Color("#E67E22"), Color("#16A085"), Color("#E84393")]


static func label(text: String, size: int = 44, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(color: Color, radius: int = 36, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	if border_width > 0:
		s.border_color = border
		s.set_border_width_all(border_width)
	return s


static func button(text: String, color: Color, size: int = 44, min_height: int = 130, text_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", size)
	style_button(b, color, text_color)
	return b


static func style_button(b: Button, color: Color, text_color: Color = Color.WHITE) -> void:
	var normal := box(color)
	normal.shadow_color = Color(0, 0, 0, 0.15)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", box(color.lerp(Color("#BBBBBB"), 0.6)))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, text_color)
	b.add_theme_color_override("font_disabled_color", text_color.lerp(Color("#EEEEEE"), 0.4))


static func card(color: Color = CARD, radius: int = 40) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(color, radius)
	s.shadow_color = Color(0, 0, 0, 0.08)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", s)
	return p


static func vbox(separation: int = 24) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 24) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func margin(child: Control, side: int = 48, top: int = 48) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", top)
	m.add_child(child)
	return m


static func grade_name(grade: int) -> String:
	var names := {1: "الأول", 2: "الثاني", 3: "الثالث", 4: "الرابع", 5: "الخامس", 6: "السادس",
		7: "السابع", 8: "الثامن", 9: "التاسع", 10: "العاشر", 11: "الحادي عشر", 12: "الثاني عشر"}
	return "الصف " + names.get(grade, str(grade))


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
