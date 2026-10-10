extends Node
## The kids' profiles and their progress (stars per lesson, questions to review), saved to user://.

const DEFAULTS_PATH := "res://data/profiles_default.json"
const SAVE_VERSION := 1

var path := "user://save.json"
var profiles: Array[Dictionary] = []
## profile id -> {"stars": {lesson_key: int}, "review": {question_key: true}, "answered": int, "correct": int}
var progress: Dictionary = {}
var current_id := ""


func _ready() -> void:
	load_save()


func current() -> Dictionary:
	return get_profile(current_id)


func get_profile(id: String) -> Dictionary:
	for p in profiles:
		if p.id == id:
			return p
	return {}


func select(id: String) -> void:
	current_id = id


## Kids up to grade 5 get the picture-reveal style and read-aloud; older kids get the lock style.
func is_young(profile: Dictionary = {}) -> bool:
	var p := profile if not profile.is_empty() else current()
	return int(p.get("grade", 0)) <= 5


static func lesson_key(book_id: String, unit_id: String, lesson_id: String) -> String:
	return "%s/%s/%s" % [book_id, unit_id, lesson_id]


func stars(lesson_key_: String, id: String = "") -> int:
	return int(_progress(id if id != "" else current_id).stars.get(lesson_key_, 0))


func unit_stars(book_id: String, unit_data: Dictionary, id: String = "") -> int:
	var total := 0
	for l in unit_data.get("lessons", []):
		total += stars(lesson_key(book_id, unit_data.id, l.id), id)
	return total


## Records one finished quiz. Stars only ever go up; wrong answers join the review list,
## right answers leave it.
func record_quiz(lesson_key_: String, earned_stars: int, results: Array) -> void:
	var p := _progress(current_id)
	if lesson_key_ != "":
		p.stars[lesson_key_] = maxi(int(p.stars.get(lesson_key_, 0)), earned_stars)
	for r in results:
		p.answered = int(p.answered) + 1
		if r.correct:
			p.correct = int(p.correct) + 1
			p.review.erase(r.key)
		else:
			p.review[r.key] = true
	save()


func review_keys(book_id: String = "", id: String = "") -> Array[String]:
	var out: Array[String] = []
	for key in _progress(id if id != "" else current_id).review:
		if book_id == "" or str(key).begins_with(book_id + "/"):
			out.append(key)
	return out


func _progress(id: String) -> Dictionary:
	if not progress.has(id):
		progress[id] = {"stars": {}, "review": {}, "answered": 0, "correct": 0}
	return progress[id]


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({"version": SAVE_VERSION, "profiles": profiles, "progress": progress}, "\t"))


func load_save() -> void:
	profiles.clear()
	progress = {}
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
	if data.get("profiles", []).is_empty():
		var defaults = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_PATH))
		data["profiles"] = defaults.get("profiles", []) if typeof(defaults) == TYPE_DICTIONARY else []
	for p in data.profiles:
		p.grade = int(p.grade)
		profiles.append(p)
	progress = data.get("progress", {})
	for id in progress:
		var p: Dictionary = progress[id]
		for k in ["stars", "review"]:
			if typeof(p.get(k)) != TYPE_DICTIONARY:
				p[k] = {}
		p.answered = int(p.get("answered", 0))
		p.correct = int(p.get("correct", 0))


func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_save()
