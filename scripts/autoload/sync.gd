extends Node
## Sends finished rounds to the parent dashboard and brings back the tests the parent assigned.
## The game works fully offline: rounds wait in user://sync.json until a sync succeeds.
## Contract: docs/sync_api.md. Server address and key are set on the parents screen (Settings).

signal synced(ok: bool, message: String)

const TIMEOUT := 15.0
const MAX_EVENTS := 500

var path := "user://sync.json"
var events: Array = []
var assignments: Array = []
## Ids of parent adjustments this phone already applied; sent back as "applied" until the server stops
## listing them (that means it has them).
var adjust_done: Array = []
var last_sync := ""
var busy := false
var _http: HTTPRequest
var _sent_ids: Array = []


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_sync_done)
	load_state()
	if configured():
		sync_now.call_deferred()


func configured() -> bool:
	return server_url() != "" and str(Settings.get_value("device_key", "")) != ""


func server_url() -> String:
	return str(Settings.get_value("server_url", "")).strip_edges().trim_suffix("/")


## Adds one finished round to the queue (called by Profiles.finish_round) and tries to send it.
func record(profile_id: String, kind: String, lesson_key: String, book: String, unit: String,
		stars: int, results: Array, coins: int) -> void:
	var assignment := ""
	var title := ""
	if kind == "assignment":
		assignment = lesson_key.trim_prefix("assignment/")
		title = str(assignment_by_id(assignment).get("title", ""))
		_mark_local_done(assignment, stars)
	elif lesson_key.count("/") == 2:
		var parts := lesson_key.split("/")
		for l in Content.unit(parts[0], parts[1]).get("lessons", []):
			if l.id == parts[2]:
				title = str(l.title)
	elif kind == "unit":
		title = str(Content.unit(book, unit).get("title", ""))
	var correct := 0
	var wrong: Array = []
	for r in results:
		if r.correct:
			correct += 1
		else:
			wrong.append(str(r.key))
	events.append({"id": "e-%d-%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000],
		"profile": profile_id, "kind": kind, "lesson_key": lesson_key if kind == "lesson" else "",
		"book": book, "unit": unit, "title": title, "stars": stars, "correct": correct,
		"total": results.size(), "coins": coins, "assignment": assignment, "wrong": wrong,
		"at": Time.get_datetime_string_from_system()})
	save_state()
	if configured():
		sync_now.call_deferred()


## The request body: all queued rounds plus the current state of every kid who played on this phone.
func build_body() -> Dictionary:
	var kids: Array = []
	var summary := {}
	for p in Profiles.profiles:
		kids.append({"id": p.id, "name": p.name, "grade": int(p.grade)})
		# The whole progress of each kid, with the time it last changed: the server keeps the newest one.
		summary[p.id] = Profiles.info(p.id).duplicate(true)
	# The server takes at most MAX_EVENTS per request; the rest go on the next sync.
	return {"device": Settings.device_id(), "profiles": kids, "events": events.slice(0, MAX_EVENTS), "summary": summary,
		"applied": adjust_done.duplicate()}


func sync_now() -> void:
	if busy or not configured():
		return
	busy = true
	var body := build_body()
	_sent_ids = body.events.map(func(e): return e.id)
	var err := _http.request(server_url() + "/api/sync", _headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		busy = false
		synced.emit(false, "تعذّر الاتصال (%d)" % err)


func _on_sync_done(result: int, code: int, _headers_: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		synced.emit(false, _error_text(result, code))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.get("ok", false):
		synced.emit(false, "رد غير مفهوم من السيرفر")
		return
	apply_response(data, _sent_ids)
	synced.emit(true, "تمت المزامنة")
	if not events.is_empty():
		sync_now.call_deferred()


## Drops the rounds the server now has, keeps its list of assignments and applies the parent's adjustments.
func apply_response(data: Dictionary, sent_ids: Array) -> void:
	events = events.filter(func(e): return not sent_ids.has(e.id))
	assignments = data.get("assignments", [])
	last_sync = Time.get_datetime_string_from_system()
	# Newest wins: a kid's state from the server replaces this phone's only when it changed later.
	for pid in data.get("kids", {}):
		if str(data.kids[pid].get("changed_at", "")) > str(Profiles.info(pid).get("changed_at", "")):
			Profiles.adopt_state(pid, data.kids[pid])
	var new_adjustments := false
	if data.has("adjustments"):
		var listed: Array = []
		for a in data.adjustments:
			listed.append(str(a.id))
			if not adjust_done.has(str(a.id)):
				Profiles.apply_adjustment(a)
				adjust_done.append(str(a.id))
				new_adjustments = true
		# Ids the server no longer lists were applied and acknowledged by it.
		adjust_done = adjust_done.filter(func(id): return listed.has(id))
	save_state()
	if new_adjustments:
		sync_now.call_deferred()  # tells the server right away


## Calls back with (ok, message): checks the address and key without sending anything.
func ping(url: String, key: String, callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		http.queue_free()
		callback.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, _error_text(result, code)))
	var err := http.request(url.strip_edges().trim_suffix("/") + "/api/ping", ["X-Device-Key: " + key.strip_edges()])
	if err != OK:
		http.queue_free()
		callback.call(false, "العنوان غير صحيح")


func _headers() -> PackedStringArray:
	return ["Content-Type: application/json", "X-Device-Key: " + str(Settings.get_value("device_key", "")).strip_edges()]


func _error_text(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "ما في اتصال بالسيرفر"
	if code == 401 or code == 403:
		return "مفتاح الجهاز غلط"
	if code == 200:
		return "الاتصال شغّال"
	return "خطأ من السيرفر (%d)" % code


## Open and finished assignments of one kid (finished ones stay until the parent gives the reward).
func assignments_for(profile_id: String) -> Array:
	return assignments.filter(func(a): return str(a.get("profile", "")) == profile_id)


func assignment_by_id(id: String) -> Dictionary:
	for a in assignments:
		if str(a.get("id", "")) == id:
			return a
	return {}


## The questions of an assignment: all questions of its lessons.
func assignment_questions(a: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in a.get("lesson_keys", []):
		var parts: PackedStringArray = str(key).split("/")
		if parts.size() == 3:
			out.append_array(Content.lesson_questions(parts[0], parts[1], parts[2]))
	return out


## Shows the result right away, before the server confirms it.
func _mark_local_done(id: String, stars: int) -> void:
	var a := assignment_by_id(id)
	if a.is_empty():
		return
	a.best_stars = maxi(int(a.get("best_stars", 0)), stars)
	if a.get("done_at") == null and stars >= int(a.get("min_stars", 1)):
		a.done_at = Time.get_datetime_string_from_system()


func save_state() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"events": events, "assignments": assignments, "adjust_done": adjust_done,
			"last_sync": last_sync}))


func load_state() -> void:
	events = []
	assignments = []
	adjust_done = []
	last_sync = ""
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY:
		events = data.get("events", [])
		assignments = data.get("assignments", [])
		adjust_done = data.get("adjust_done", [])
		last_sync = str(data.get("last_sync", ""))


## Clears the queue and assignments (tests).
func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_state()
