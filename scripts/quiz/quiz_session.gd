class_name QuizSession
extends RefCounted
## One round of questions. Pure logic (no UI) so it can be tested headless.
##
## Answer formats passed to answer():
##   mcq   -> int, index into the *shuffled* choices of current()
##   tf    -> bool
##   match -> Array[int]: for each left item i (in order), the index of the chosen right item
##            in current().right
##   order -> Array[int]: indices into current().shuffled, in the order the player tapped them

const MAX_QUESTIONS := 8

var questions: Array[Dictionary] = []
var results: Array[Dictionary] = []
var index := 0
var _rng := RandomNumberGenerator.new()


func _init(source: Array[Dictionary], max_count: int = MAX_QUESTIONS, seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	var pool := source.duplicate(true)
	_shuffle(pool)
	for q in pool.slice(0, mini(max_count, pool.size())):
		questions.append(_prepare(q))


func current() -> Dictionary:
	return questions[index] if index < questions.size() else {}


func is_done() -> bool:
	return index >= questions.size()


func count() -> int:
	return questions.size()


## Checks an answer for the current question, records it and returns whether it was right.
## Call next() to move on.
func answer(value: Variant) -> bool:
	var q := current()
	var ok := is_correct(q, value)
	results.append({"key": q.get("key", ""), "correct": ok})
	return ok


func next() -> void:
	index += 1


func correct_count() -> int:
	var n := 0
	for r in results:
		if r.correct:
			n += 1
	return n


func stars() -> int:
	return stars_for(correct_count(), count())


static func stars_for(correct: int, total: int) -> int:
	if total <= 0:
		return 0
	var ratio := float(correct) / total
	if ratio >= 0.9:
		return 3
	if ratio >= 0.7:
		return 2
	if ratio >= 0.5:
		return 1
	return 0


static func is_correct(q: Dictionary, value: Variant) -> bool:
	match q.get("type", ""):
		"mcq":
			return typeof(value) == TYPE_INT and value == int(q.answer)
		"tf":
			return typeof(value) == TYPE_BOOL and value == bool(q.answer)
		"match":
			if typeof(value) != TYPE_ARRAY or value.size() != q.left.size():
				return false
			for i in value.size():
				if int(value[i]) < 0 or int(value[i]) >= q.right_origin.size() or q.right_origin[int(value[i])] != i:
					return false
			return true
		"order":
			if typeof(value) != TYPE_ARRAY or value.size() != q.items.size():
				return false
			for i in value.size():
				if q.shuffled_origin[int(value[i])] != i:
					return false
			return true
	return false


## Text of the right answer, shown after a wrong try.
static func correct_text(q: Dictionary) -> String:
	match q.get("type", ""):
		"mcq":
			return str(q.choices[int(q.answer)])
		"tf":
			return "صح" if q.answer else "خطأ"
		"match":
			var parts := PackedStringArray()
			for p in q.pairs:
				parts.append("%s = %s" % [p[0], p[1]])
			return "\n".join(parts)
		"order":
			return " ، ".join(PackedStringArray(q.items.map(func(x): return str(x))))
	return ""


func _prepare(q: Dictionary) -> Dictionary:
	match q.get("type", ""):
		"mcq":
			var order := range(q.choices.size())
			_shuffle(order)
			var shuffled: Array = []
			for i in order:
				shuffled.append(q.choices[i])
			q.answer = order.find(int(q.answer))
			q.choices = shuffled
		"match":
			q.left = q.pairs.map(func(p): return str(p[0]))
			var origin := range(q.pairs.size())
			_shuffle(origin)
			q.right_origin = origin
			q.right = origin.map(func(i): return str(q.pairs[i][1]))
		"order":
			var origin := range(q.items.size())
			while origin.size() > 1 and origin == range(q.items.size()):
				_shuffle(origin)
			q.shuffled_origin = origin
			q.shuffled = origin.map(func(i): return str(q.items[i]))
	return q


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
