class_name ToddlerArt
extends RefCounted
## Drawings for the toddler games, all made from polygons (the font has no emoji).
##
## A picture lives in a 1000 x 1000 box and is a list of fill regions plus details:
##   {"id", "regions": [{"polys": [PackedVector2Array], "color": Color}], "details": [...]}
## A detail is {"poly", "color"} (a filled dark spot: eyes, nostrils) or {"line", "width"} (a stroke).
## Regions are drawn in order, so a later region covers an earlier one; taps hit the last one first.

const OUTLINE := Color("#2B2B3A")
const UNIT := 1000.0

const COLORS := [
	{"id": "red", "name": "أحمر", "color": Color("#E53935")},
	{"id": "yellow", "name": "أصفر", "color": Color("#FDD835")},
	{"id": "blue", "name": "أزرق", "color": Color("#1E88E5")},
	{"id": "green", "name": "أخضر", "color": Color("#43A047")},
	{"id": "orange", "name": "برتقالي", "color": Color("#FB8C00")},
	{"id": "pink", "name": "زهري", "color": Color("#EC407A")},
	{"id": "purple", "name": "بنفسجي", "color": Color("#8E24AA")},
	{"id": "brown", "name": "بني", "color": Color("#8D6E63")},
]

## Pictures for colouring, the animal grid and the puzzles.
const COLORING := ["sun", "apple", "fish", "house", "flower", "cat"]
const ANIMALS := ["cat", "cow", "sheep", "chicken", "duck", "dog", "lion", "banana", "apple"]
const PUZZLES := ["house", "fish", "sun", "cow", "flower", "duck", "lion", "cat"]

const SHAPES := ["circle", "square", "triangle", "star", "heart"]

static var _cache := {}


static func color_by_id(id: String) -> Dictionary:
	for c in COLORS:
		if c.id == id:
			return c
	return COLORS[0]


# ---------------------------------------------------------------- geometry helpers

static func circle(c: Vector2, r: float, n: int = 48) -> PackedVector2Array:
	return ellipse(c, r, r, 0.0, n)


static func ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func poly(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)


static func mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(UNIT - pts[i].x, pts[i].y))
	return out


static func star(c: Vector2, r_out: float, r_in: float, points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in points * 2:
		var radius := r_out if k % 2 == 0 else r_in
		var a := -PI / 2.0 + k * PI / points
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	return pts


static func heart(c: Vector2, r: float, n: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 2.0) * (r / 17.0))
	return pts


static func arc(c: Vector2, r: float, from: float, to: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## The part of `a` inside `b` (the biggest piece when there are several).
static func clip(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var parts := Geometry2D.intersect_polygons(a, b)
	var best := PackedVector2Array()
	for p in parts:
		if p.size() > best.size():
			best = p
	return best


## A toy shape (for the shapes board) of "radius" r around c.
static func shape(kind: String, c: Vector2, r: float) -> PackedVector2Array:
	match kind:
		"square":
			return rect(c.x - r * 0.8, c.y - r * 0.8, r * 1.6, r * 1.6)
		"triangle":
			return poly([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.75), c + Vector2(-r * 0.95, r * 0.75)])
		"star":
			return star(c + Vector2(0, r * 0.08), r * 1.05, r * 0.5)
		"heart":
			return heart(c, r)
	return circle(c, r * 0.9)


# ---------------------------------------------------------------- drawing

## Draws a picture. `fills` overrides the region colours (same length as regions), `xf` maps the
## 1000-box to the canvas. Each region gets a thick outline only on its outside edge.
static func draw_picture(ci: CanvasItem, pic: Dictionary, fills: Array, xf: Transform2D, outline_w: float = 10.0, alpha: float = 1.0) -> void:
	var regions: Array = pic.regions
	for i in regions.size():
		var col: Color = fills[i] if i < fills.size() else regions[i].color
		col.a *= alpha
		var line := Color(OUTLINE, alpha)
		for p in regions[i].polys:
			var pts: PackedVector2Array = xf * p
			if pts.size() < 3:
				continue
			pts.append(pts[0])
			ci.draw_polyline(pts, line, outline_w * 2.0, true)
		for p in regions[i].polys:
			if p.size() >= 3:
				ci.draw_colored_polygon(xf * p, col)
	for d in pic.get("details", []):
		if d.has("poly"):
			if d.poly.size() >= 3:
				ci.draw_colored_polygon(xf * d.poly, Color(d.get("color", OUTLINE), alpha))
		elif d.line.size() >= 2:
			ci.draw_polyline(xf * d.line, Color(d.get("color", OUTLINE), alpha), d.get("width", 12.0) * xf.get_scale().x, true)


## A transform that fits the 1000-box into `r`, centred.
static func fit(r: Rect2) -> Transform2D:
	var s := minf(r.size.x, r.size.y) / UNIT
	var o := r.position + (r.size - Vector2(UNIT, UNIT) * s) / 2.0
	return Transform2D(0.0, Vector2(s, s), 0.0, o)


## Index of the region under `p` (in 1000-box coordinates), or -1.
static func region_at(pic: Dictionary, p: Vector2) -> int:
	var regions: Array = pic.regions
	for i in range(regions.size() - 1, -1, -1):
		for poly_ in regions[i].polys:
			if Geometry2D.is_point_in_polygon(p, poly_):
				return i
	return -1


## A point inside region i that no later region covers (for tests and hints), in 1000-box units.
static func region_point(pic: Dictionary, i: int) -> Vector2:
	for poly_ in pic.regions[i].polys:
		var c := Vector2.ZERO
		for v in poly_:
			c += v
		c /= poly_.size()
		var tries := [c]
		for v in poly_:
			tries.append(c.lerp(v, 0.5))
			tries.append(c.lerp(v, 0.8))
		for t in tries:
			if region_at(pic, t) == i:
				return t
	return Vector2(-1, -1)


## The same picture cut to `r` (1000-box units): used for puzzle pieces.
static func cut(pic: Dictionary, r: Rect2) -> Dictionary:
	var box := rect(r.position.x, r.position.y, r.size.x, r.size.y)
	var regions := []
	for reg in pic.regions:
		var polys := []
		for p in reg.polys:
			polys.append_array(Geometry2D.intersect_polygons(p, box))
		regions.append({"polys": polys, "color": reg.color})
	var details := []
	for d in pic.get("details", []):
		if d.has("poly"):
			for part in Geometry2D.intersect_polygons(d.poly, box):
				details.append({"poly": part, "color": d.get("color", OUTLINE)})
		else:
			for part in Geometry2D.intersect_polyline_with_polygon(d.line, box):
				details.append({"line": part, "width": d.get("width", 12.0)})
	return {"id": pic.id, "regions": regions, "details": details}


## Draws a toy shape with an outline.
static func draw_shape(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, outline_w: float = 8.0) -> void:
	var pts := shape(kind, c, r)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, outline_w * 2.0, true)
	ci.draw_colored_polygon(pts, col)


## A shiny ball.
static func draw_ball(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r + 5, col.darkened(0.45))
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(-r * 0.32, -r * 0.32), r * 0.22, Color(1, 1, 1, 0.55))


## A balloon (an oval with a knot and a string), centred on the oval.
static func draw_balloon(ci: CanvasItem, c: Vector2, r: float, col: Color, sway: float = 0.0) -> void:
	var string := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		string.append(c + Vector2(sin(t * 6.0 + sway) * 14.0, r * 1.2 + t * r * 1.3))
	ci.draw_polyline(string, Color("#5D5D6E"), 5.0, true)
	ci.draw_colored_polygon(poly([c + Vector2(0, r * 1.1), c + Vector2(-r * 0.18, r * 1.32), c + Vector2(r * 0.18, r * 1.32)]), col.darkened(0.2))
	var body := ellipse(c, r * 0.9, r * 1.15)
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, col.darkened(0.35), 6.0, true)
	ci.draw_colored_polygon(body, col)
	ci.draw_colored_polygon(ellipse(c + Vector2(-r * 0.35, -r * 0.45), r * 0.14, r * 0.28, 0.5, 20), Color(1, 1, 1, 0.5))


# ---------------------------------------------------------------- pictures

static func picture(id: String) -> Dictionary:
	if not _cache.has(id):
		_cache[id] = _build(id)
	return _cache[id]


static func _region(polys: Array, col: String) -> Dictionary:
	return {"polys": polys, "color": Color(col)}


static func _dot(c: Vector2, r: float) -> Dictionary:
	return {"poly": circle(c, r, 24)}


static func _line(pts: PackedVector2Array, w: float = 12.0) -> Dictionary:
	return {"line": pts, "width": w}


static func _eyes(y: float, dx: float, r: float) -> Array:
	return [_dot(Vector2(500 - dx, y), r), _dot(Vector2(500 + dx, y), r),
		{"poly": circle(Vector2(500 - dx - r * 0.3, y - r * 0.35), r * 0.32, 12), "color": Color.WHITE},
		{"poly": circle(Vector2(500 + dx - r * 0.3, y - r * 0.35), r * 0.32, 12), "color": Color.WHITE}]


static func _smile(c: Vector2, r: float) -> Dictionary:
	return _line(arc(c, r, PI * 0.2, PI * 0.8), 12.0)


static func _build(id: String) -> Dictionary:
	var regions := []
	var details := []
	match id:
		"sun":
			var even := []
			var odd := []
			for k in 8:
				var a := TAU * k / 8.0 - PI / 2.0
				var ray := poly([Vector2(500, 500) + Vector2.from_angle(a - 0.2) * 280,
					Vector2(500, 500) + Vector2.from_angle(a) * 470,
					Vector2(500, 500) + Vector2.from_angle(a + 0.2) * 280])
				(even if k % 2 == 0 else odd).append(ray)
			regions = [_region(even, "#FB8C00"), _region(odd, "#FFB300"), _region([circle(Vector2(500, 500), 260, 64)], "#FDD835"),
				_region([circle(Vector2(380, 570), 45), circle(Vector2(620, 570), 45)], "#F48FB1")]
			details = _eyes(450, 90, 30) + [_smile(Vector2(500, 500), 140)]
		"apple":
			var body := Geometry2D.merge_polygons(circle(Vector2(400, 600), 250, 64), circle(Vector2(600, 600), 250, 64))[0]
			regions = [_region([poly([Vector2(478, 230), Vector2(520, 222), Vector2(535, 380), Vector2(492, 385)])], "#6D4C41"),
				_region([ellipse(Vector2(640, 270), 120, 52, -0.5)], "#43A047"),
				_region([body], "#E53935"),
				_region([ellipse(Vector2(300, 520), 38, 85, 0.35)], "#FFFFFF")]
		"fish":
			var body := ellipse(Vector2(450, 520), 310, 200, 0.0, 64)
			regions = [_region([poly([Vector2(380, 360), Vector2(520, 190), Vector2(620, 360)]),
					poly([Vector2(400, 680), Vector2(480, 800), Vector2(570, 690)])], "#FB8C00"),
				_region([poly([Vector2(690, 520), Vector2(940, 330), Vector2(940, 710)])], "#EF6C00"),
				_region([body], "#1E88E5"),
				_region([clip(rect(470, 280, 70, 500), body), clip(rect(600, 300, 60, 450), body)], "#FDD835"),
				_region([circle(Vector2(300, 470), 60)], "#FFFFFF"),
				_region([circle(Vector2(110, 250), 42), circle(Vector2(170, 130), 30)], "#B3E5FC")]
			details = [_dot(Vector2(290, 475), 28), _line(arc(Vector2(250, 560), 55, PI * 0.15, PI * 0.6), 10)]
		"house":
			var windows := [rect(250, 520, 140, 140), rect(610, 520, 140, 140)]
			regions = [_region([rect(640, 160, 90, 220)], "#8D6E63"),
				_region([poly([Vector2(120, 440), Vector2(500, 130), Vector2(880, 440)])], "#E53935"),
				_region([rect(190, 440, 620, 430)], "#FDD835"),
				_region([rect(435, 620, 130, 250)], "#8D6E63"),
				_region(windows, "#B3E5FC")]
			for w in [250, 610]:
				details.append(_line(PackedVector2Array([Vector2(w + 70, 520), Vector2(w + 70, 660)]), 10))
				details.append(_line(PackedVector2Array([Vector2(w, 590), Vector2(w + 140, 590)]), 10))
			details.append(_dot(Vector2(540, 750), 14))
		"flower":
			var petals := []
			for k in 6:
				petals.append(circle(Vector2(500, 330) + Vector2.from_angle(TAU * k / 6.0 - PI / 2) * 165, 100))
			regions = [_region([rect(482, 450, 36, 390)], "#43A047"),
				_region([ellipse(Vector2(380, 690), 105, 45, 0.5), ellipse(Vector2(620, 650), 105, 45, -0.5)], "#66BB6A"),
				_region([poly([Vector2(320, 820), Vector2(680, 820), Vector2(630, 985), Vector2(370, 985)])], "#8D6E63"),
				_region(petals, "#EC407A"),
				_region([circle(Vector2(500, 330), 100)], "#FDD835")]
			details = _eyes(310, 35, 14) + [_line(arc(Vector2(500, 330), 50, PI * 0.25, PI * 0.75), 9)]
		"cat":
			var ear := poly([Vector2(190, 420), Vector2(240, 110), Vector2(450, 270)])
			var inner := poly([Vector2(245, 370), Vector2(270, 190), Vector2(390, 285)])
			regions = [_region([ear, mirror(ear)], "#FB8C00"),
				_region([inner, mirror(inner)], "#F48FB1"),
				_region([ellipse(Vector2(500, 570), 340, 300, 0.0, 64)], "#FFB74D"),
				_region([ellipse(Vector2(500, 700), 160, 100)], "#FFF3E0"),
				_region([poly([Vector2(455, 625), Vector2(545, 625), Vector2(500, 680)])], "#F06292")]
			details = _eyes(510, 130, 40)
			for s in [-1, 1]:
				for dy in [-25, 15]:
					details.append(_line(PackedVector2Array([Vector2(500 + s * 170, 690 + dy * 0.3), Vector2(500 + s * 330, 660 + dy * 1.6)]), 8))
			details.append(_line(PackedVector2Array([Vector2(500, 680), Vector2(500, 720)]), 9))
			details.append(_line(arc(Vector2(465, 720), 35, PI * 0.1, PI * 0.9), 9))
			details.append(_line(arc(Vector2(535, 720), 35, PI * 0.1, PI * 0.9), 9))
		"cow":
			var head := ellipse(Vector2(500, 470), 270, 290, 0.0, 64)
			var horn := poly([Vector2(330, 260), Vector2(250, 90), Vector2(400, 220)])
			regions = [_region([horn, mirror(horn)], "#FFF8E1"),
				_region([ellipse(Vector2(170, 380), 130, 62, 0.35), ellipse(Vector2(830, 380), 130, 62, -0.35)], "#F8BBD0"),
				_region([head], "#FFFFFF"),
				_region([clip(circle(Vector2(360, 320), 120), head), clip(circle(Vector2(680, 520), 100), head)], "#5D4037"),
				_region([ellipse(Vector2(500, 730), 240, 155, 0.0, 64)], "#F8BBD0")]
			details = _eyes(450, 110, 36) + [{"poly": ellipse(Vector2(430, 730), 28, 40)}, {"poly": ellipse(Vector2(570, 730), 28, 40)}]
		"sheep":
			var wool := [circle(Vector2(500, 520), 300, 64)]
			for k in 12:
				wool.append(circle(Vector2(500, 520) + Vector2(cos(TAU * k / 12.0) * 330, sin(TAU * k / 12.0) * 300), 110))
			regions = [_region(wool, "#F5F5F5"),
				_region([ellipse(Vector2(270, 470), 120, 50, 0.35), ellipse(Vector2(730, 470), 120, 50, -0.35)], "#6D4C41"),
				_region([ellipse(Vector2(500, 580), 175, 230, 0.0, 64)], "#8D6E63"),
				_region([circle(Vector2(420, 380), 75), circle(Vector2(500, 350), 85), circle(Vector2(580, 380), 75)], "#FFFFFF")]
			details = [{"poly": circle(Vector2(430, 540), 38), "color": Color.WHITE}, {"poly": circle(Vector2(570, 540), 38), "color": Color.WHITE},
				_dot(Vector2(435, 548), 20), _dot(Vector2(565, 548), 20),
				{"poly": ellipse(Vector2(470, 690), 16, 22)}, {"poly": ellipse(Vector2(530, 690), 16, 22)},
				_smile(Vector2(500, 700), 50)]
		"chicken":
			var foot := poly([Vector2(410, 830), Vector2(350, 950), Vector2(470, 950)])
			regions = [_region([circle(Vector2(430, 245), 60), circle(Vector2(500, 215), 68), circle(Vector2(570, 245), 60)], "#E53935"),
				_region([foot, mirror(foot)], "#FB8C00"),
				_region([ellipse(Vector2(500, 560), 300, 300, 0.0, 64)], "#FFFFFF"),
				_region([ellipse(Vector2(250, 600), 70, 140, 0.35), ellipse(Vector2(750, 600), 70, 140, -0.35)], "#FFF59D"),
				_region([ellipse(Vector2(500, 600), 35, 55)], "#E53935"),
				_region([poly([Vector2(440, 480), Vector2(560, 480), Vector2(500, 570)])], "#FB8C00")]
			details = _eyes(410, 100, 34)
		"duck":
			var wing := ellipse(Vector2(230, 700), 80, 135, 0.45)
			regions = [_region([ellipse(Vector2(500, 720), 300, 210, 0.0, 64)], "#FDD835"),
				_region([wing, mirror(wing)], "#FBC02D"),
				_region([circle(Vector2(500, 390), 220, 64)], "#FFEE58"),
				_region([poly([Vector2(470, 190), Vector2(490, 90), Vector2(520, 130), Vector2(545, 175)])], "#FFEE58"),
				_region([ellipse(Vector2(500, 470), 135, 55)], "#FB8C00")]
			details = _eyes(360, 90, 32) + [_line(PackedVector2Array([Vector2(380, 470), Vector2(620, 470)]), 8)]
		"dog":
			var head := ellipse(Vector2(500, 480), 280, 300, 0.0, 64)
			regions = [_region([head], "#D7A86E"),
				_region([clip(circle(Vector2(630, 400), 100), head)], "#8D6E63"),
				_region([ellipse(Vector2(225, 470), 90, 200, 0.3), ellipse(Vector2(775, 470), 90, 200, -0.3)], "#6D4C41"),
				_region([ellipse(Vector2(500, 790), 45, 65)], "#F06292"),
				_region([ellipse(Vector2(500, 660), 175, 125)], "#FFF3E0"),
				_region([ellipse(Vector2(500, 590), 62, 42)], "#2B2B3A")]
			details = _eyes(420, 110, 36) + [_line(PackedVector2Array([Vector2(500, 630), Vector2(500, 680)]), 9),
				_line(arc(Vector2(460, 680), 40, PI * 0.1, PI * 0.9), 9), _line(arc(Vector2(540, 680), 40, PI * 0.1, PI * 0.9), 9)]
		"lion":
			var mane := [circle(Vector2(500, 500), 320, 64)]
			for k in 14:
				mane.append(circle(Vector2(500, 500) + Vector2.from_angle(TAU * k / 14.0) * 330, 115))
			regions = [_region(mane, "#E65100"),
				_region([circle(Vector2(320, 290), 75), circle(Vector2(680, 290), 75)], "#FFB74D"),
				_region([circle(Vector2(500, 520), 255, 64)], "#FFCA28"),
				_region([ellipse(Vector2(500, 650), 145, 100)], "#FFF3E0"),
				_region([poly([Vector2(445, 590), Vector2(555, 590), Vector2(500, 645)])], "#6D4C41")]
			details = _eyes(470, 100, 34) + [_line(PackedVector2Array([Vector2(500, 645), Vector2(500, 680)]), 9),
				_line(arc(Vector2(465, 680), 35, PI * 0.1, PI * 0.9), 9), _line(arc(Vector2(535, 680), 35, PI * 0.1, PI * 0.9), 9)]
		"banana":
			var pts := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0
				pts.append(Vector2(110 + 760 * t, 430 + 330 * sin(PI * t)))
			for i in range(23, 0, -1):
				var t := float(i) / 24.0
				pts.append(Vector2(110 + 760 * t, 430 + 150 * sin(PI * t)))
			regions = [_region([pts], "#FDD835"),
				_region([poly([Vector2(850, 420), Vector2(905, 330), Vector2(950, 350), Vector2(895, 445)])], "#6D4C41"),
				_region([circle(Vector2(118, 434), 22, 16)], "#5D4037")]
			details = [_line(arc(Vector2(490, 150), 470, PI * 0.36, PI * 0.64, 20), 8)]
	return {"id": id, "regions": regions, "details": details}
