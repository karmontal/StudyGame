extends Control
## Root of the game: a background and one screen at a time.

const SCREENS := {
	"profiles": preload("res://scripts/ui/profile_screen.gd"),
	"books": preload("res://scripts/ui/books_screen.gd"),
	"map": preload("res://scripts/ui/map_screen.gd"),
	"quiz": preload("res://scripts/ui/quiz_screen.gd"),
	"result": preload("res://scripts/ui/result_screen.gd"),
}

var screen: Screen


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	goto("profiles")


func goto(screen_name: String, screen_args: Dictionary = {}) -> void:
	if screen != null:
		screen.queue_free()
	screen = SCREENS[screen_name].new()
	screen.name = screen_name
	screen.main = self
	screen.args = screen_args
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	screen.build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and screen != null:
		if screen.name == "profiles":
			get_tree().quit()
		else:
			screen.go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and screen != null and screen.name != "profiles":
		screen.go_back()
