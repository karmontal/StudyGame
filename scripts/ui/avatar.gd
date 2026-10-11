class_name Avatar
extends Control
## A colored circle with the first letter of a name (stand-in until the kids' pictures exist).

var color := Color.GRAY
var letter := ""


static func make(name_: String, color_: Color, diameter: float = 220.0) -> Avatar:
	var a := Avatar.new()
	a.color = color_
	a.letter = name_.substr(0, 1)
	a.custom_minimum_size = Vector2(diameter, diameter)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c, r, color)
	draw_circle(c, r * 0.86, color.lightened(0.15))
	var font := get_theme_default_font()
	var fs := int(r * 0.95)
	var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w / 2.0, c.y + fs * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
