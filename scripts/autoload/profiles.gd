extends Node
## The kids' profiles and their progress (stars, review list, coins, streak, badges, stickers),
## saved to user://.

const DEFAULTS_PATH := "res://data/profiles_default.json"
const STICKERS_PATH := "res://data/stickers.json"
const SAVE_VERSION := 2
const BADGE_COINS := 25

var path := "user://save.json"
var profiles: Array[Dictionary] = []
## profile id -> {"stars": {lesson_key: int}, "review": {question_key: true}, "answered": int,
##   "correct": int, "rounds": int, "fixed": int, "coins": int, "xp": int,
##   "streak": {"days": int, "best": int, "last": "YYYY-MM-DD"}, "daily": {"last": "YYYY-MM-DD", "count": int},
##   "speed_best": int, "badges": {id: true}, "stickers": {id: true}, "week": {"id": int, "coins": int}}
var progress: Dictionary = {}
var current_id := ""
## Stickers the kids can buy with coins: [{id, name, price, file}].
var sticker_catalog: Array[Dictionary] = []
## Tests set this to pretend it is another day ("YYYY-MM-DD").
var today_override := ""


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(STICKERS_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		for st in parsed.get("stickers", []):
			sticker_catalog.append(st)
	load_save()


func today() -> String:
	return today_override if today_override != "" else Time.get_date_string_from_system()


static func day_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00")) / 86400


## Monday-based week number, so the weekly board resets every Monday.
static func week_number(date: String) -> int:
	return (day_number(date) + 3) / 7


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
	p.rounds = int(p.rounds) + 1
	for r in results:
		p.answered = int(p.answered) + 1
		if r.correct:
			p.correct = int(p.correct) + 1
			if p.review.has(r.key):
				p.fixed = int(p.fixed) + 1
			p.review.erase(r.key)
		else:
			p.review[r.key] = true
	save()


## Records a finished round and pays out coins, streak and badges.
## kind: "lesson", "unit", "review", "daily", "speed" or "assignment" (lesson_key "assignment/<id>").
## Every round is also queued for the parent dashboard (Sync). Returns a summary for the result screen:
## {coins, lines, new_badges, level_before, level_after, streak, speed_best, new_best}.
func finish_round(kind: String, lesson_key_: String, earned_stars: int, results: Array,
		book_id: String = "", unit_id: String = "") -> Dictionary:
	var p := _progress(current_id)
	var level_before := Rewards.level_for(int(p.xp))
	var day := today()
	var first_today: bool = p.streak.last != day
	if first_today:
		var yesterday := day_number(day) - 1
		p.streak.days = int(p.streak.days) + 1 if p.streak.last != "" and day_number(p.streak.last) == yesterday else 1
		p.streak.best = maxi(int(p.streak.best), int(p.streak.days))
		p.streak.last = day
	var bonus := Rewards.streak_bonus(int(p.streak.days)) if first_today else 0
	record_quiz(lesson_key_ if kind == "lesson" else "", earned_stars, results)
	if kind == "daily":
		p.daily.last = day
		p.daily.count = int(p.daily.count) + 1
	if kind == "speed":
		p.speed_last = day
	var correct := 0
	for r in results:
		if r.correct:
			correct += 1
	var new_best := false
	if kind == "speed" and correct > int(p.speed_best):
		p.speed_best = correct
		new_best = true
	var pay := Rewards.round_coins(results, earned_stars, kind, bonus)
	var extra := {"perfect": kind != "speed" and results.size() > 0 and correct == results.size(),
		"combo": Rewards.best_combo(results), "unit_master": _unit_mastered(book_id, unit_id)}
	var new_badges: Array[String] = []
	for id in Rewards.earned_badges(p, extra):
		if not p.badges.has(id):
			p.badges[id] = true
			new_badges.append(id)
	if not new_badges.is_empty():
		pay.lines.append(["أوسمة جديدة × %d" % new_badges.size(), new_badges.size() * BADGE_COINS])
		pay.total += new_badges.size() * BADGE_COINS
	_add_coins(p, int(pay.total))
	# Level and family badges can only be checked after the coins land.
	extra["family_goal"] = family_week_coins() >= Rewards.FAMILY_WEEK_GOAL
	for id in Rewards.earned_badges(p, extra):
		if not p.badges.has(id):
			p.badges[id] = true
			new_badges.append(id)
	save()
	Sync.record(current_id, kind, lesson_key_, book_id, unit_id, earned_stars, results, int(pay.total))
	return {"coins": pay.total, "lines": pay.lines, "new_badges": new_badges, "level_before": level_before,
		"level_after": Rewards.level_for(int(p.xp)), "streak": int(p.streak.days),
		"speed_best": int(p.speed_best), "new_best": new_best}


func _add_coins(p: Dictionary, amount: int) -> void:
	p.coins = int(p.coins) + amount
	p.xp = int(p.xp) + amount
	var week := week_number(today())
	if int(p.week.id) != week:
		p.week = {"id": week, "coins": 0}
	p.week.coins = int(p.week.coins) + amount


func _unit_mastered(book_id: String, unit_id: String) -> bool:
	if book_id == "" or unit_id == "":
		return false
	var u := Content.unit(book_id, unit_id)
	var any := false
	for l in u.get("lessons", []):
		if l.get("questions", []).is_empty():
			continue
		any = true
		if stars(lesson_key(book_id, unit_id, l.id)) < 3:
			return false
	return any


func info(id: String = "") -> Dictionary:
	return _progress(id if id != "" else current_id)


func coins(id: String = "") -> int:
	return int(info(id).coins)


func daily_done(id: String = "") -> bool:
	return info(id).daily.last == today()


## The speed challenge is once a day, like the daily challenge.
func speed_done(id: String = "") -> bool:
	return str(info(id).speed_last) == today()


## Coins earned this week (the brothers-and-sisters board on the profile screen).
func week_coins(id: String) -> int:
	var w: Dictionary = info(id).week
	return int(w.coins) if int(w.id) == week_number(today()) else 0


## Coins all the kids earned together this week (the family goal).
func family_week_coins() -> int:
	var total := 0
	for p in profiles:
		total += week_coins(p.id)
	return total


## A parent's decision from the dashboard, applied once by the phone (see Sync.apply_response).
## kind: "coins" (take away coins and xp, never below 0), "lesson" (remove the stars of a lesson),
## "badge" (take a badge away for good), "sticker" (take a sticker away).
func apply_adjustment(a: Dictionary) -> void:
	var id := str(a.get("profile", ""))
	if get_profile(id).is_empty():
		return
	var p := info(id)
	var target := str(a.get("target", ""))
	match str(a.get("kind", "")):
		"coins":
			var amount := int(a.get("amount", 0))
			p.coins = maxi(0, int(p.coins) - amount)
			p.xp = maxi(0, int(p.xp) - amount)
		"lesson":
			p.stars.erase(target)
		"badge":
			p.badges.erase(target)
			p.badges_revoked[target] = true
		"sticker":
			p.stickers.erase(target)
		_:
			return
	save()


## Streak days, or 0 when the kid missed a day (the streak is broken until they play again).
func live_streak(id: String = "") -> int:
	var s: Dictionary = info(id).streak
	if s.last == "":
		return 0
	return int(s.days) if day_number(today()) - day_number(s.last) <= 1 else 0


func sticker(id: String) -> Dictionary:
	for st in sticker_catalog:
		if st.id == id:
			return st
	return {}


func has_sticker(id: String) -> bool:
	return info().stickers.has(id)


## Buys a sticker with coins. Returns the new badge ids (may be empty), or null when it can't be bought.
func buy_sticker(id: String) -> Variant:
	var p := info()
	var st := sticker(id)
	if st.is_empty() or p.stickers.has(id) or int(p.coins) < int(st.price):
		return null
	p.coins = int(p.coins) - int(st.price)
	p.stickers[id] = true
	# Buying happens between rounds, so send it now; otherwise the dashboard only sees it after the next round.
	Sync.sync_now.call_deferred()
	var new_badges: Array[String] = []
	for b in Rewards.earned_badges(p):
		if not p.badges.has(b):
			p.badges[b] = true
			new_badges.append(b)
	save()
	return new_badges


func review_keys(book_id: String = "", id: String = "") -> Array[String]:
	var out: Array[String] = []
	for key in _progress(id if id != "" else current_id).review:
		if book_id == "" or str(key).begins_with(book_id + "/"):
			out.append(key)
	return out


func _progress(id: String) -> Dictionary:
	if not progress.has(id):
		progress[id] = {}
	_fill_defaults(progress[id])
	return progress[id]


## Older saves miss the newer fields; JSON also turns ints into floats.
static func _fill_defaults(p: Dictionary) -> void:
	for k in ["stars", "review", "badges", "stickers", "badges_revoked"]:
		if typeof(p.get(k)) != TYPE_DICTIONARY:
			p[k] = {}
	for k in ["answered", "correct", "rounds", "fixed", "coins", "xp", "speed_best"]:
		p[k] = int(p.get(k, 0))
	if typeof(p.get("streak")) != TYPE_DICTIONARY:
		p.streak = {}
	p.streak = {"days": int(p.streak.get("days", 0)), "best": int(p.streak.get("best", 0)), "last": str(p.streak.get("last", ""))}
	if typeof(p.get("daily")) != TYPE_DICTIONARY:
		p.daily = {}
	p.daily = {"last": str(p.daily.get("last", "")), "count": int(p.daily.get("count", 0))}
	p.speed_last = str(p.get("speed_last", ""))
	if typeof(p.get("week")) != TYPE_DICTIONARY:
		p.week = {}
	p.week = {"id": int(p.week.get("id", 0)), "coins": int(p.week.get("coins", 0))}


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
	var defaults = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_PATH))
	var default_profiles: Array = defaults.get("profiles", []) if typeof(defaults) == TYPE_DICTIONARY else []
	var saved: Array = data.get("profiles", [])
	# Saves from before a kid was added get the new kid too (matched by id).
	var ids := saved.map(func(p): return str(p.get("id", "")))
	for p in default_profiles:
		if not ids.has(p.id):
			saved.append(p)
	for p in saved:
		p.grade = int(p.grade)
		profiles.append(p)
	progress = data.get("progress", {})
	for id in progress:
		_fill_defaults(progress[id])


func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_save()
