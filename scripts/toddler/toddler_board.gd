class_name ToddlerBoard
extends Control
## A drawing surface for the toddler games. It turns finger (InputEventScreenTouch/Drag) and mouse
## input into one stream of `down`, `moved`, `up` signals (one finger at a time), calls `painter`
## to draw, and draws the happy effects on top: sparkles and confetti.
##
## With emulate_touch_from_mouse / emulate_mouse_from_touch Godot sends every press twice, once as
## the emulated twin (device DEVICE_ID_EMULATION). Those twins are ignored.

signal down(pos: Vector2)
signal moved(pos: Vector2)
signal up(pos: Vector2)

const NONE := -2
const MOUSE := -1

var painter: Callable  # func(board: ToddlerBoard) -> void
var _pointer := NONE
var _effects := []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == NONE:
			_pointer = event.index
			down.emit(event.position)
		elif not event.pressed and event.index == _pointer:
			_pointer = NONE
			up.emit(event.position)
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _pointer:
			moved.emit(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pointer == NONE:
			_pointer = MOUSE
			down.emit(event.position)
		elif not event.pressed and _pointer == MOUSE:
			_pointer = NONE
			up.emit(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pointer == MOUSE:
		moved.emit(event.position)
		accept_event()


func is_held() -> bool:
	return _pointer != NONE


func _process(delta: float) -> void:
	for e in _effects:
		e.life -= delta
		e.vel += e.get("gravity", Vector2.ZERO) * delta
		e.pos += e.vel * delta
		e.rot += e.spin * delta
	_effects = _effects.filter(func(e): return e.life > 0.0 and e.pos.y < size.y + 60)
	queue_redraw()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
	for e in _effects:
		var a := clampf(e.life / e.max_life * 2.0, 0.0, 1.0)
		var col: Color = e.color
		col.a *= a
		if e.kind == "spark":
			draw_colored_polygon(ToddlerArt.star(e.pos, e.size, e.size * 0.45), col)
		else:
			draw_set_transform(e.pos, e.rot, Vector2.ONE)
			draw_rect(Rect2(-e.size / 2.0, -e.size * 0.3, e.size, e.size * 0.6), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A little burst of stars where the finger touched.
func sparkle(pos: Vector2, color: Color = Color("#FFD54F"), count: int = 8) -> void:
	for i in count:
		var a := TAU * i / count + _rng.randf_range(-0.2, 0.2)
		_effects.append({"kind": "spark", "pos": pos, "vel": Vector2.from_angle(a) * _rng.randf_range(220, 420),
			"color": color, "life": 0.7, "max_life": 0.7, "size": _rng.randf_range(18, 30), "rot": 0.0, "spin": 0.0,
			"gravity": Vector2(0, 300)})


## Confetti falling from the top of the board.
func confetti(count: int = 90) -> void:
	for i in count:
		var c: Dictionary = ToddlerArt.COLORS[i % ToddlerArt.COLORS.size()]
		_effects.append({"kind": "confetti", "pos": Vector2(_rng.randf_range(0, size.x), _rng.randf_range(-400, -20)),
			"vel": Vector2(_rng.randf_range(-80, 80), _rng.randf_range(250, 520)), "color": c.color,
			"life": 3.5, "max_life": 3.5, "size": _rng.randf_range(22, 36), "rot": _rng.randf_range(0, TAU),
			"spin": _rng.randf_range(-6, 6)})


func effect_count() -> int:
	return _effects.size()


# Test helpers: feed real input events through _gui_input.

func send_tap(pos: Vector2, touch := false) -> void:
	_send(pos, true, touch)
	_send(pos, false, touch)


func send_drag(from: Vector2, to: Vector2, touch := false, steps: int = 6) -> void:
	_send(from, true, touch)
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		if touch:
			var d := InputEventScreenDrag.new()
			d.position = p
			_gui_input(d)
		else:
			var m := InputEventMouseMotion.new()
			m.position = p
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			_gui_input(m)
	_send(to, false, touch)


func _send(pos: Vector2, pressed: bool, touch: bool) -> void:
	if touch:
		var t := InputEventScreenTouch.new()
		t.position = pos
		t.pressed = pressed
		_gui_input(t)
	else:
		var b := InputEventMouseButton.new()
		b.position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		_gui_input(b)
