extends Node
## Loads the curriculum: data/subjects.json, data/books/index.json and one JSON file per book.
## A book file holds units → lessons → questions. Books without a file are listed as "coming soon".

const SUBJECTS_PATH := "res://data/subjects.json"
const INDEX_PATH := "res://data/books/index.json"
const QUESTION_TYPES := ["mcq", "tf", "match", "order"]

var subjects: Dictionary = {}
var books: Array[Dictionary] = []
var _book_cache: Dictionary = {}


func _ready() -> void:
	subjects = _load_json(SUBJECTS_PATH)
	var index: Dictionary = _load_json(INDEX_PATH)
	books.clear()
	for b in index.get("books", []):
		books.append(b)


func books_for_grade(grade: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in books:
		if int(b.grade) == grade:
			out.append(b)
	return out


func subject_name(subject_id: String) -> String:
	return subjects.get(subject_id, {}).get("name", subject_id)


func subject_color(subject_id: String) -> Color:
	return Color(subjects.get(subject_id, {}).get("color", "#888888"))


func has_book_data(book_id: String) -> bool:
	var meta := book_meta(book_id)
	return not meta.is_empty() and FileAccess.file_exists(meta.file)


func book_meta(book_id: String) -> Dictionary:
	for b in books:
		if b.id == book_id:
			return b
	return {}


## Full book data, or {} when the book has no content file yet.
func book(book_id: String) -> Dictionary:
	if _book_cache.has(book_id):
		return _book_cache[book_id]
	if not has_book_data(book_id):
		return {}
	var data := _load_json(book_meta(book_id).file)
	_book_cache[book_id] = data
	return data


func unit(book_id: String, unit_id: String) -> Dictionary:
	for u in book(book_id).get("units", []):
		if u.id == unit_id:
			return u
	return {}


func lesson(book_id: String, unit_id: String, lesson_id: String) -> Dictionary:
	for l in unit(book_id, unit_id).get("lessons", []):
		if l.id == lesson_id:
			return l
	return {}


## Questions of one lesson, each tagged with a stable "key" (book/unit/lesson/index) used for progress.
func lesson_questions(book_id: String, unit_id: String, lesson_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var qs: Array = lesson(book_id, unit_id, lesson_id).get("questions", [])
	for i in qs.size():
		var q: Dictionary = qs[i].duplicate(true)
		q.key = "%s/%s/%s/%d" % [book_id, unit_id, lesson_id, i]
		out.append(q)
	return out


func unit_questions(book_id: String, unit_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in unit(book_id, unit_id).get("lessons", []):
		out.append_array(lesson_questions(book_id, unit_id, l.id))
	return out


func question_by_key(key: String) -> Dictionary:
	var parts := key.split("/")
	if parts.size() != 4:
		return {}
	var qs := lesson_questions(parts[0], parts[1], parts[2])
	var i := int(parts[3])
	return qs[i] if i >= 0 and i < qs.size() else {}


func book_lang(book_id: String) -> String:
	return book(book_id).get("lang", "ar")


## Returns a list of problems in a book's data (empty = valid). Used by the tests.
func validate_book(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in ["id", "title", "units"]:
		if not data.has(key):
			errors.append("book missing '%s'" % key)
	var unit_ids := {}
	for u in data.get("units", []):
		var where := "%s/%s" % [data.get("id", "?"), u.get("id", "?")]
		if unit_ids.has(u.get("id")):
			errors.append(where + ": duplicate unit id")
		unit_ids[u.get("id")] = true
		if not u.has("title") or not u.has("lessons"):
			errors.append(where + ": unit needs title and lessons")
		var lesson_ids := {}
		for l in u.get("lessons", []):
			var lw := where + "/" + str(l.get("id", "?"))
			if lesson_ids.has(l.get("id")):
				errors.append(lw + ": duplicate lesson id")
			lesson_ids[l.get("id")] = true
			if not l.has("title"):
				errors.append(lw + ": lesson needs a title")
			var qs: Array = l.get("questions", [])
			for i in qs.size():
				errors.append_array(validate_question(qs[i], "%s#%d" % [lw, i]))
	return errors


func validate_question(q: Dictionary, where: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var t: String = q.get("type", "")
	if t not in QUESTION_TYPES:
		return PackedStringArray([where + ": unknown type '%s'" % t])
	if str(q.get("q", "")).strip_edges() == "":
		errors.append(where + ": empty question text")
	match t:
		"mcq":
			var choices: Array = q.get("choices", [])
			if choices.size() < 2 or choices.size() > 4:
				errors.append(where + ": mcq needs 2-4 choices")
			var a = q.get("answer", -1)
			if typeof(a) not in [TYPE_INT, TYPE_FLOAT] or int(a) < 0 or int(a) >= choices.size():
				errors.append(where + ": mcq answer index out of range")
			var seen := {}
			for c in choices:
				if seen.has(str(c)):
					errors.append(where + ": duplicate choice '%s'" % c)
				seen[str(c)] = true
		"tf":
			if typeof(q.get("answer")) != TYPE_BOOL:
				errors.append(where + ": tf answer must be true/false")
		"match":
			var pairs: Array = q.get("pairs", [])
			if pairs.size() < 2 or pairs.size() > 5:
				errors.append(where + ": match needs 2-5 pairs")
			for p in pairs:
				if typeof(p) != TYPE_ARRAY or p.size() != 2:
					errors.append(where + ": each pair needs two items")
		"order":
			var items: Array = q.get("items", [])
			if items.size() < 3 or items.size() > 6:
				errors.append(where + ": order needs 3-6 items")
	return errors


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("missing " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("bad JSON in " + path)
		return {}
	return parsed
