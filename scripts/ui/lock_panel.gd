class_name LockPanel
extends HBoxContainer
## The older kids' reward: a combination lock. Each right answer reveals one digit of the code.

var digits: Array[Label] = []
var code: Array[int] = []


static func make(count: int, code_seed: int) -> LockPanel:
	var p := LockPanel.new()
	p.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_theme_constant_override("separation", 14)
	var rng := RandomNumberGenerator.new()
	rng.seed = code_seed
	for i in count:
		p.code.append(rng.randi_range(0, 9))
		var d := UI.label("?", 56, Color.WHITE)
		d.custom_minimum_size = Vector2(96, 120)
		d.add_theme_stylebox_override("normal", UI.box(Color("#34495E"), 20))
		p.add_child(d)
		p.digits.append(d)
	return p


func set_digit(i: int, correct: bool) -> void:
	if i < 0 or i >= digits.size():
		return
	var d := digits[i]
	d.text = str(code[i]) if correct else "-"
	d.add_theme_stylebox_override("normal", UI.box(UI.GOOD if correct else UI.BAD, 20))
	d.pivot_offset = d.size / 2.0
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector2(1.15, 1.15), 0.12)
	tw.tween_property(d, "scale", Vector2.ONE, 0.12)
