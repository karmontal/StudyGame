class_name FamilyContest
extends RefCounted
## Rules of the family contest (pure, no UI): the kids take turns on one phone, each answers a question
## from their own grade, and every right answer is worth the same single point. Solo or two teams.
## The toddler gets picture questions ("وين البقرة؟") so she can play too.

const TEAM_NAMES := ["الفريق الأزرق", "الفريق البرتقالي"]
const TEAM_COLORS := [Color("#2980B9"), Color("#E67E22")]
const PICTURE_ANIMALS := ["cat", "cow", "sheep", "chicken", "duck", "dog", "lion", "banana", "apple"]
const PICTURE_COLORS := ["red", "yellow", "blue", "green"]

var players: Array[String] = []
var teams := false
var team_of := {}  # profile id -> 0 or 1
var rounds := 3
var order: Array[String] = []  # who plays each turn
var turn := 0
var points := {}  # profile id -> int
var results := {}  # profile id -> [{key, correct}]
var _pools := {}  # profile id -> Array[Dictionary], questions not asked yet
var _rng := RandomNumberGenerator.new()


static func make(ids: Array, teams_: bool, rounds_: int, rng_seed: int = 0) -> FamilyContest:
	var c := FamilyContest.new()
	c._rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())
	c.teams = teams_
	c.rounds = maxi(1, rounds_)
	for id in ids:
		c.players.append(str(id))
		c.points[str(id)] = 0
		c.results[str(id)] = []
	if teams_:
		c.team_of = split_teams(c.players)
	c.order = c._build_order()
	return c


## Two teams of mixed ages: oldest to youngest, dealt A B B A A B ... so both get big and small kids.
static func split_teams(ids: Array) -> Dictionary:
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b): return _grade(a) > _grade(b))
	var out := {}
	for i in sorted.size():
		out[sorted[i]] = 0 if i % 4 == 0 or i % 4 == 3 else 1
	return out


static func _grade(id: String) -> int:
	return int(Profiles.get_profile(id).get("grade", 0))


static func is_toddler(id: String) -> bool:
	return bool(Profiles.get_profile(id).get("toddler", false))


func team_members(t: int) -> Array[String]:
	var out: Array[String] = []
	for id in players:
		if int(team_of.get(id, -1)) == t:
			out.append(id)
	return out


## Solo: everyone once per round. Teams: the teams alternate and both get the same number of turns
## (the bigger team's size), so a smaller team's kids simply play more often.
func _build_order() -> Array[String]:
	var out: Array[String] = []
	for r in rounds:
		if not teams:
			out.append_array(players)
			continue
		var a := team_members(0)
		var b := team_members(1)
		var n := maxi(a.size(), b.size())
		for k in n:
			if not a.is_empty():
				out.append(a[(r * n + k) % a.size()])
			if not b.is_empty():
				out.append(b[(r * n + k) % b.size()])
	return out


func done() -> bool:
	return turn >= order.size()


func current_player() -> String:
	return order[turn] if not done() else ""


func turns_per_round() -> int:
	return order.size() / rounds


func round_number() -> int:
	return mini(turn / turns_per_round() + 1, rounds)


## The next question for a kid: from their grade's lessons they finished (any grade lesson when they
## have finished too few), never the same one twice in a game. Toddlers get a picture question.
func next_question(id: String) -> Dictionary:
	if is_toddler(id):
		return _picture_question()
	if not _pools.has(id) or _pools[id].is_empty():
		var grade := _grade(id)
		var pool := Content.grade_questions(grade, ["mcq", "tf"], true, id)
		if pool.size() < rounds * 2:
			pool = Content.grade_questions(grade, ["mcq", "tf"])
		_shuffle(pool)
		_pools[id] = pool
	if _pools[id].is_empty():
		return {}
	return _pools[id].pop_back()


func _picture_question() -> Dictionary:
	if _rng.randi() % 2 == 0:
		var options := _pick(PICTURE_ANIMALS, 3)
		return {"type": "picture", "kind": "animal", "options": options, "answer": _rng.randi() % 3}
	var colors := _pick(PICTURE_COLORS, 3)
	return {"type": "picture", "kind": "color", "options": colors, "answer": _rng.randi() % 3}


func _pick(from: Array, n: int) -> Array:
	var a := from.duplicate()
	_shuffle(a)
	return a.slice(0, n)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Records the current player's answer and moves to the next turn. Returns the player.
func answer(correct: bool, key: String = "") -> String:
	var id := current_player()
	if id == "":
		return ""
	if correct:
		points[id] = int(points[id]) + 1
	if key != "":
		results[id].append({"key": key, "correct": correct})
	turn += 1
	return id


func team_points(t: int) -> int:
	var total := 0
	for id in team_members(t):
		total += int(points[id])
	return total


## Solo: the kids with the most points. Teams: [0], [1] or [0, 1] for a draw.
func winners() -> Array:
	if teams:
		var a := team_points(0)
		var b := team_points(1)
		return [0] if a > b else ([1] if b > a else [0, 1])
	var best := -1
	for id in players:
		best = maxi(best, int(points[id]))
	return players.filter(func(id): return int(points[id]) == best)


## Players from most to fewest points (stable for ties).
func ranking() -> Array[String]:
	var out := players.duplicate()
	out.sort_custom(func(a, b): return int(points[a]) > int(points[b]) or \
		(int(points[a]) == int(points[b]) and players.find(a) < players.find(b)))
	return out
