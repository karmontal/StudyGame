extends ToddlerScreen
## Tap and hear: nine big drawn animals and fruits. A tap makes it bounce and say its name and
## its sound ("بقرة! مووو").

const TILE := Vector2(320, 450)
const BGS := ["#FFE0B2", "#C8E6C9", "#BBDEFB", "#F8BBD0", "#FFF9C4", "#D1C4E9", "#FFCCBC", "#DCEDC8", "#B2EBF2"]

var last_tapped := ""


func setup() -> void:
	bg_color = Color("#FFF8E1")
	for i in ToddlerArt.ANIMALS.size():
		var kind: String = ToddlerArt.ANIMALS[i]
		var b := ToddlerButton.make("Animal_" + kind, TILE, Color(BGS[i]),
			func(ci: CanvasItem, r: Rect2): ToddlerArt.draw_picture(ci, ToddlerArt.picture(kind), [], ToddlerArt.fit(r), 8.0))
		b.position = Vector2(30 + (i % 3) * (TILE.x + 30), 215 + (i / 3) * (TILE.y + 90))
		add_child(b)
		b.pressed.connect(func(): tap(kind))  # after add_child, so it plays after the button click
	ToddlerVoice.say("game_animals")


func tap(kind: String) -> void:
	last_tapped = kind
	var b: ToddlerButton = find_child("Animal_" + kind, false, false)
	if b != null:
		b.bounce()
		background.sparkle(b.position + b.size / 2.0 + Vector2(0, -b.size.y * 0.35), Color(BGS[ToddlerArt.ANIMALS.find(kind)]).darkened(0.2))
	Sfx.play("boing")
	ToddlerVoice.say("a_" + kind)
