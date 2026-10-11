class_name Avatar
extends Control
## A kid's round picture: their 3D portrait from res://assets/avatars/<id>.png (or .jpg, fetched in CI
## by tools/fetch_art.sh) inside a colored ring, or a colored circle with the first letter of the name.

const DIR := "res://assets/avatars/"

var color := Color.GRAY
var letter := ""
var texture: Texture2D


static func make(name_: String, color_: Color, diameter: float = 220.0, id := "") -> Avatar:
	var a := Avatar.new()
	a.color = color_
	a.letter = name_.substr(0, 1)
	a.texture = picture(id)
	a.custom_minimum_size = Vector2(diameter, diameter)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


## The kid's portrait, or null when it was not downloaded.
static func picture(id: String) -> Texture2D:
	if id == "":
		return null
	for ext in ["png", "jpg", "webp"]:
		var p: String = DIR + id + "." + ext
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c + Vector2(0, r * 0.05), r, Color(0, 0, 0, 0.12))  # soft shadow
	draw_circle(c, r, color)
	var inner := r * 0.9
	if texture == null:
		draw_circle(c, inner, color.lightened(0.15))
		var font := get_theme_default_font()
		var fs := int(r * 0.95)
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w / 2.0, c.y + fs * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		return
	draw_circle(c, inner, Color.WHITE)
	# The picture cropped to a circle: a round polygon whose UVs take the centered square of the image.
	var ts := texture.get_size()
	var side := minf(ts.x, ts.y)
	var uv_off := Vector2((ts.x - side) / 2.0 / ts.x, (ts.y - side) / 2.0 / ts.y)
	var uv_scale := Vector2(side / ts.x, side / ts.y)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 64:
		var d := Vector2.from_angle(TAU * i / 64.0)
		points.append(c + d * inner)
		uvs.append(uv_off + (d * 0.5 + Vector2(0.5, 0.5)) * uv_scale)
	draw_colored_polygon(points, Color.WHITE, uvs, texture)
