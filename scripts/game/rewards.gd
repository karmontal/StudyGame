class_name Rewards
extends RefCounted
## Coins, levels and badges. Pure rules (no saving) so they can be tested headless;
## Profiles.finish_round() applies them to a kid's progress.

const COIN_PER_CORRECT := 10
const COMBO_BONUS := 5          # each right answer after two in a row
const STAR_BONUS := 5           # per star earned in the round
const PERFECT_BONUS := 20       # every answer right
const DAILY_BONUS := 50         # finishing the daily challenge
const STREAK_BONUS_PER_DAY := 10  # first round of the day: 10 coins per streak day, up to 70
const STREAK_BONUS_MAX := 70
const XP_PER_LEVEL := 300

const LEVEL_TITLES := ["مبتدئ", "مستكشف", "شاطر", "نبيه", "متفوق", "عبقري", "بطل", "أسطورة"]

## id, name, how to earn it, color. Checked after every round by earned_badges().
const BADGES := [
	{"id": "first_round", "name": "أول خطوة", "desc": "خلّص أول جولة", "color": "#3498DB"},
	{"id": "perfect", "name": "علامة كاملة", "desc": "جاوب كل أسئلة جولة صح", "color": "#2ECC71"},
	{"id": "combo5", "name": "سلسلة نار", "desc": "5 إجابات صح ورا بعض", "color": "#E67E22"},
	{"id": "streak3", "name": "مثابر", "desc": "العب 3 أيام ورا بعض", "color": "#E84393"},
	{"id": "streak7", "name": "أسبوع كامل", "desc": "العب 7 أيام ورا بعض", "color": "#9B59B6"},
	{"id": "correct50", "name": "50 إجابة", "desc": "50 إجابة صحيحة", "color": "#16A085"},
	{"id": "correct200", "name": "200 إجابة", "desc": "200 إجابة صحيحة", "color": "#1ABC9C"},
	{"id": "correct500", "name": "500 إجابة", "desc": "500 إجابة صحيحة", "color": "#0E7C66"},
	{"id": "daily1", "name": "تحدي اليوم", "desc": "خلّص أول تحدي يومي", "color": "#F39C12"},
	{"id": "daily7", "name": "بطل التحديات", "desc": "خلّص 7 تحديات يومية", "color": "#D35400"},
	{"id": "speed10", "name": "سريع البرق", "desc": "10 إجابات صح في تحدي السرعة", "color": "#F1C40F"},
	{"id": "speed20", "name": "الصاروخ", "desc": "20 إجابة صح في تحدي السرعة", "color": "#C0392B"},
	{"id": "review10", "name": "تعلّم من أخطائه", "desc": "صحّح 10 أسئلة من المراجعة", "color": "#2980B9"},
	{"id": "unit_master", "name": "نجم الوحدة", "desc": "3 نجوم في كل دروس وحدة", "color": "#F7B500"},
	{"id": "level5", "name": "متفوق", "desc": "وصّل المستوى 5", "color": "#8E44AD"},
	{"id": "stickers5", "name": "صاحب الألبوم", "desc": "اجمع 5 ملصقات", "color": "#E74C3C"},
]


## Coins for one round. results: [{correct: bool}, ...]. Returns {"total": int, "lines": [[text, coins], ...]}.
static func round_coins(results: Array, stars: int, kind: String = "lesson", streak_bonus: int = 0) -> Dictionary:
	var lines: Array = []
	var correct := 0
	var combo := 0
	var combo_coins := 0
	for r in results:
		if r.correct:
			correct += 1
			combo += 1
			if combo >= 3:
				combo_coins += COMBO_BONUS
		else:
			combo = 0
	if correct > 0:
		lines.append(["إجابات صحيحة × %d" % correct, correct * COIN_PER_CORRECT])
	if combo_coins > 0:
		lines.append(["مكافأة السلسلة", combo_coins])
	if stars > 0 and kind != "speed":
		lines.append(["النجوم", stars * STAR_BONUS])
	if kind != "speed" and results.size() > 0 and correct == results.size():
		lines.append(["كلها صح!", PERFECT_BONUS])
	if kind == "daily":
		lines.append(["تحدي اليوم", DAILY_BONUS])
	if streak_bonus > 0:
		lines.append(["أيام متتالية", streak_bonus])
	var total := 0
	for l in lines:
		total += int(l[1])
	return {"total": total, "lines": lines}


static func best_combo(results: Array) -> int:
	var best := 0
	var combo := 0
	for r in results:
		combo = combo + 1 if r.correct else 0
		best = maxi(best, combo)
	return best


static func streak_bonus(days: int) -> int:
	return mini(days * STREAK_BONUS_PER_DAY, STREAK_BONUS_MAX)


static func level_for(xp: int) -> int:
	return xp / XP_PER_LEVEL + 1


## 0..1 progress inside the current level.
static func level_progress(xp: int) -> float:
	return float(xp % XP_PER_LEVEL) / XP_PER_LEVEL


static func level_title(level: int) -> String:
	return LEVEL_TITLES[clampi(level - 1, 0, LEVEL_TITLES.size() - 1)]


static func badge(id: String) -> Dictionary:
	for b in BADGES:
		if b.id == id:
			return b
	return {}


## Badge ids a kid's progress qualifies for. `extra` carries facts about the round just played:
## perfect (bool), combo (int), unit_master (bool).
static func earned_badges(p: Dictionary, extra: Dictionary = {}) -> Array[String]:
	var owned: Dictionary = p.get("badges", {})
	var best_streak := int(p.get("streak", {}).get("best", 0))
	var correct := int(p.get("correct", 0))
	var daily := int(p.get("daily", {}).get("count", 0))
	var speed := int(p.get("speed_best", 0))
	var checks := {
		"first_round": int(p.get("rounds", 0)) >= 1,
		"perfect": extra.get("perfect", false),
		"combo5": int(extra.get("combo", 0)) >= 5,
		"streak3": best_streak >= 3,
		"streak7": best_streak >= 7,
		"correct50": correct >= 50,
		"correct200": correct >= 200,
		"correct500": correct >= 500,
		"daily1": daily >= 1,
		"daily7": daily >= 7,
		"speed10": speed >= 10,
		"speed20": speed >= 20,
		"review10": int(p.get("fixed", 0)) >= 10,
		"unit_master": extra.get("unit_master", false),
		"level5": level_for(int(p.get("xp", 0))) >= 5,
		"stickers5": p.get("stickers", {}).size() >= 5,
	}
	var out: Array[String] = []
	for b in BADGES:
		if checks.get(b.id, false) or owned.has(b.id):
			out.append(b.id)
	return out
