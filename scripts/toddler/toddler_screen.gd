class_name ToddlerScreen
extends Screen
## Base for the toddler screens (laid out for the 1080 x 1920 portrait viewport). Adds a soft
## background that sparkles wherever it is touched, a parents' exit that needs a long press, and
## the play-time limit: after PLAY_LIMIT seconds of toddler play the rest screen comes up.
## No text to read, no timers, no losing, no coins or stars.

const PLAY_LIMIT := 600.0
const TOP := 190.0  # height of the strip with the exit button

## Seconds of toddler play since the last rest (kept while the app runs).
static var play_seconds := 0.0

var counts_time := true
var bg_color := Color("#FFF6E5")
var background: ToddlerBoard
var exit_hold: ToddlerHold
var _leaving := false


func build() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	background = ToddlerBoard.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.painter = func(ci: CanvasItem): ci.draw_rect(Rect2(Vector2.ZERO, ci.size), bg_color)
	background.down.connect(func(p: Vector2):
		background.sparkle(p)
		Sfx.play("boing"))
	add_child(background)
	setup()
	exit_hold = ToddlerHold.make("back", 140.0)
	exit_hold.name = "Exit"
	exit_hold.position = Vector2(1080 - 170, 25)
	exit_hold.held.connect(leave)
	add_child(exit_hold)
	var hint := UI.label("للأهل: اضغط مطوّلاً", 22, UI.MUTED)
	hint.name = "ExitHint"
	hint.position = Vector2(1080 - 330, 165)
	hint.size = Vector2(320, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


## Builds the screen's own nodes.
func setup() -> void:
	pass


## The long-press exit: games go back to the toddler hub.
func leave() -> void:
	_go("toddler")


## Android back: inside a game it returns to the hub (harmless); the hub and the rest screen
## ignore it so only a parent's long press leaves.
func go_back() -> void:
	_go("toddler")


func _go(screen_name: String) -> void:
	if _leaving:
		return
	_leaving = true
	main.goto(screen_name)


func _process(delta: float) -> void:
	if not counts_time or _leaving:
		return
	play_seconds += delta
	if play_seconds >= PLAY_LIMIT:
		_go("toddler_rest")


## A full-area board below the exit strip, for games that draw and drag.
func make_board(painter_: Callable) -> ToddlerBoard:
	var b := ToddlerBoard.new()
	b.name = "Board"
	b.position = Vector2(0, TOP)
	b.size = Vector2(1080, 1920 - TOP)
	b.painter = painter_
	add_child(b)
	return b

