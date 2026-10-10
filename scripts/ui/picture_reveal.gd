class_name PictureReveal
extends Control
## The young kids' reward: a picture hidden under tiles. Each right answer lifts one tile.
## Uses a picture from res://assets/rewards/ when there is one, otherwise a drawn scene.

const REWARDS_DIR := "res://assets/rewards/"

var tiles := 8
var texture: Texture2D
var _alpha: PackedFloat32Array
var _cols := 4
var _seed := 0


static func make(tile_count: int, picture_seed: int) -> PictureReveal:
	var p := PictureReveal.new()
	p.tiles = maxi(tile_count, 1)
	p._seed = picture_seed
	p.custom_minimum_size = Vector2(0, 420)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.clip_contents = true
	p._alpha.resize(p.tiles)
	p._alpha.fill(1.0)
	p._cols = ceili(sqrt(p.tiles * 2.0))
	p.texture = _pick_texture(picture_seed)
	return p


static func _pick_texture(picture_seed: int) -> Texture2D:
	var files: Array[String] = []
	if not DirAccess.dir_exists_absolute(REWARDS_DIR):
		return null
	for f in ResourceLoader.list_directory(REWARDS_DIR):
		if f.get_extension() in ["png", "jpg", "webp"]:
			files.append(REWARDS_DIR + f)
	if files.is_empty():
		return null
	files.sort()
	return load(files[absi(picture_seed) % files.size()])


func reveal(i: int) -> void:
	if i < 0 or i >= tiles:
		return
	var tw := create_tween()
	tw.tween_method(func(a: float):
		_alpha[i] = a
		queue_redraw(), 1.0, 0.0, 0.5)


func reveal_all() -> void:
	for i in tiles:
		if _alpha[i] > 0.0:
			reveal(i)


func revealed_count() -> int:
	var n := 0
	for a in _alpha:
		if a < 0.5:
			n += 1
	return n


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if texture:
		# Cover the panel, cropping the picture's middle band.
		var ts := texture.get_size()
		var scale_ := maxf(size.x / ts.x, size.y / ts.y)
		var src_size := size / scale_
		draw_texture_rect_region(texture, rect, Rect2((ts - src_size) / 2.0, src_size))
	else:
		_draw_scene(rect)
	var rows := ceili(float(tiles) / _cols)
	var tw := size.x / _cols
	var th := size.y / rows
	for i in tiles:
		if _alpha[i] <= 0.0:
			continue
		# Number tiles in reading order: right-to-left in Arabic layouts.
		var col := i % _cols
		if is_layout_rtl():
			col = _cols - 1 - col
		var r := Rect2(Vector2(col * tw, (i / _cols) * th), Vector2(tw, th)).grow(-3)
		var c := Color("#6C5CE7").lerp(Color("#00B894"), float(i) / tiles)
		c.a = _alpha[i]
		draw_rect(r, c)
		var font := get_theme_default_font()
		var label := str(i + 1)
		var fs := int(th * 0.4)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.get_center() + Vector2(-w / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, _alpha[i]))


## A simple sunny landscape, varied by seed, used until real reward pictures are added.
func _draw_scene(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var sky := Color.from_hsv(rng.randf_range(0.5, 0.62), 0.45, 0.98)
	draw_rect(rect, sky)
	draw_circle(Vector2(rect.size.x * rng.randf_range(0.15, 0.85), rect.size.y * 0.25), rect.size.y * 0.13, Color("#FFD93D"))
	for k in 3:
		var hc := Color.from_hsv(rng.randf_range(0.25, 0.4), 0.55, 0.75 - k * 0.1)
		var cx := rect.size.x * rng.randf_range(0.0, 1.0)
		draw_circle(Vector2(cx, rect.size.y * 1.15), rect.size.x * rng.randf_range(0.35, 0.55), hc)
	for k in 5:
		var x := rect.size.x * rng.randf_range(0.05, 0.95)
		var y := rect.size.y * rng.randf_range(0.75, 0.92)
		draw_circle(Vector2(x, y), 14, Color.from_hsv(rng.randf(), 0.6, 1.0))
