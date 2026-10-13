"""Read-side queries for the dashboard pages."""
import json
from collections import Counter
from datetime import datetime, timedelta

from . import db
from .content import BADGES, level_for, level_title

WEEKDAYS = ["الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"]
KIND_NAMES = {"lesson": "درس", "unit": "اختبار وحدة", "review": "مراجعة", "daily": "تحدي اليوم",
              "speed": "تحدي السرعة", "assignment": "اختبار من الأهل",
              "family": "مسابقة العيلة"}


def since(days: int, now=None) -> str:
    """Start of the last `days` calendar days, today included (7 -> midnight six days ago)."""
    now = now or datetime.now()
    return (now.date() - timedelta(days=days - 1)).strftime("%Y-%m-%dT00:00:00")


def is_lesson_key(key: str) -> bool:
    return key.count("/") == 2


def profiles(conn) -> list:
    return [dict(r) for r in conn.execute("SELECT * FROM profiles ORDER BY grade DESC, id")]


def profile(conn, pid: str):
    row = conn.execute("SELECT * FROM profiles WHERE id=?", (pid,)).fetchone()
    return dict(row) if row else None


def summary(conn, pid: str) -> dict:
    """A kid's state as the dashboard shows it: the newest state any phone sent (see db.apply_sync)."""
    row = db.kid_state(conn, pid)
    if not row:
        return {"_synced": None}
    raw = json.loads(row["data"])
    xp = int(raw.get("xp", 0) or 0)
    streak = raw.get("streak", {}) or {}
    return {
        "coins": int(raw.get("coins", 0) or 0), "xp": xp, "level": level_for(xp),
        "answered": int(raw.get("answered", 0) or 0), "correct": int(raw.get("correct", 0) or 0),
        "streak": int(streak.get("days", 0) or 0) if isinstance(streak, dict) else 0,
        "speed_best": int(raw.get("speed_best", 0) or 0),
        "badges": list((raw.get("badges", {}) or {}).keys()),
        "stickers": list((raw.get("stickers", {}) or {}).keys()),
        "stars": dict(raw.get("stars", {}) or {}),
        "_synced": row["updated_at"],
    }


def accuracy(correct, total):
    return int(100 * correct / total + 0.5) if total else None


def overview_card(conn, p: dict) -> dict:
    s = summary(conn, p["id"])
    week = since(7)
    last = conn.execute("SELECT MAX(at) AS at FROM events WHERE profile=?", (p["id"],)).fetchone()["at"]
    keys = conn.execute("SELECT DISTINCT lesson_key FROM events WHERE profile=? AND at>=?", (p["id"], week)).fetchall()
    open_count = conn.execute(
        "SELECT COUNT(*) AS n FROM assignments WHERE profile=? AND done_at IS NULL", (p["id"],)).fetchone()["n"]
    to_give = conn.execute(
        "SELECT COUNT(*) AS n FROM assignments WHERE profile=? AND done_at IS NOT NULL AND reward_given_at IS NULL",
        (p["id"],)).fetchone()["n"]
    level = int(s.get("level", 1) or 1)
    return {
        **p,
        "level": level, "level_title": level_title(level),
        "coins": s.get("coins", 0), "streak": s.get("streak", 0),
        "last": last, "synced": s["_synced"],
        "week_lessons": sum(1 for r in keys if is_lesson_key(r["lesson_key"])),
        "accuracy": accuracy(s.get("correct", 0) or 0, s.get("answered", 0) or 0),
        "open": open_count, "to_give": to_give,
    }


def lesson_tree(conn, content, p: dict, s: dict) -> list:
    """Subjects -> units -> lessons with best stars (from the summary) and last played time."""
    stars = s.get("stars", {}) or {}
    last = {r["lesson_key"]: (r["at"], r["n"]) for r in conn.execute(
        "SELECT lesson_key, MAX(at) AS at, COUNT(*) AS n FROM events WHERE profile=? GROUP BY lesson_key", (p["id"],))}
    subjects = []
    for book in content.books_for_grade(p["grade"]):
        units, done, total = [], 0, 0
        for unit in book["units"]:
            lessons = []
            for lesson in unit.get("lessons", []):
                key = f"{book['id']}/{unit['id']}/{lesson['id']}"
                st = int(stars.get(key, 0) or 0)
                at, n = last.get(key, (None, 0))
                lessons.append({"key": key, "title": lesson.get("title", key), "stars": st, "last": at, "rounds": n})
                total += 1
                done += 1 if st > 0 else 0
            units.append({"id": unit["id"], "title": unit.get("title", unit["id"]), "lessons": lessons})
        subjects.append({"book": book, "name": content.subject_name(book["subject"]),
                         "color": content.subject_color(book["subject"]), "units": units,
                         "done": done, "total": total})
    return subjects


def recent_events(conn, content, pid: str, limit: int = 30) -> list:
    rows = conn.execute("SELECT * FROM events WHERE profile=? ORDER BY at DESC LIMIT ?", (pid, limit)).fetchall()
    out = []
    for r in rows:
        e = dict(r)
        e["kind_name"] = KIND_NAMES.get(e["kind"], e["kind"])
        e["display_title"] = e["title"] or content.lesson_title(e["lesson_key"])
        out.append(e)
    return out


def badges(s: dict) -> list:
    return [BADGES.get(b, b) for b in s.get("badges", []) or []]


def stickers(content, s: dict) -> list:
    return [content.stickers.get(x, x) for x in s.get("stickers", []) or []]


def most_wrong(conn, content, pid: str, limit: int = 10) -> list:
    counts = Counter()
    for r in conn.execute("SELECT wrong FROM events WHERE profile=?", (pid,)):
        counts.update(json.loads(r["wrong"] or "[]"))
    out = []
    for key, n in counts.most_common(limit):
        q = content.question(key)
        out.append({"key": key, "count": n, "text": q["text"] if q else key,
                    "answer": q["answer"] if q else "", "lesson": q["lesson"] if q else ""})
    return out


def weekly(conn, content, pid: str, now=None) -> dict:
    now = now or datetime.now()
    start = since(7, now)
    rows = [dict(r) for r in conn.execute(
        "SELECT * FROM events WHERE profile=? AND at>=? ORDER BY at", (pid, start))]
    first_seen = {r["lesson_key"]: r["first"] for r in conn.execute(
        "SELECT lesson_key, MIN(at) AS first FROM events WHERE profile=? GROUP BY lesson_key", (pid,))}
    correct = sum(r["correct"] for r in rows)
    total = sum(r["total"] for r in rows)
    days = []
    for i in range(6, -1, -1):
        d = (now - timedelta(days=i)).date()
        day_rows = [r for r in rows if r["at"][:10] == d.isoformat()]
        days.append({"name": WEEKDAYS[d.weekday()], "date": d.strftime("%d/%m"),
                     "rounds": len(day_rows), "answered": sum(r["total"] for r in day_rows)})
    peak = max([d["answered"] for d in days] + [1])
    for d in days:
        d["pct"] = round(100 * d["answered"] / peak)
    lessons = {}
    for r in rows:
        k = r["lesson_key"]
        if not is_lesson_key(k):
            continue
        item = lessons.setdefault(k, {"key": k, "title": content.lesson_title(k, r["title"]), "stars": 0,
                                      "rounds": 0, "new": first_seen.get(k, "") >= start})
        item["stars"] = max(item["stars"], r["stars"])
        item["rounds"] += 1
    kinds = Counter(KIND_NAMES.get(r["kind"], r["kind"]) for r in rows)
    return {
        "start": (now.date() - timedelta(days=6)).strftime("%d/%m/%Y"), "end": now.strftime("%d/%m/%Y"),
        "rounds": len(rows), "answered": total, "correct": correct, "accuracy": accuracy(correct, total),
        "stars": sum(r["stars"] for r in rows), "coins": sum(r["coins"] for r in rows),
        "days": days, "lessons": sorted(lessons.values(), key=lambda x: x["title"]),
        "new_lessons": sum(1 for x in lessons.values() if x["new"]), "kinds": kinds.most_common(),
        "active_days": sum(1 for d in days if d["rounds"]),
    }


def assignments(conn, content, pid=None) -> list:
    sql = "SELECT a.*, p.name AS kid FROM assignments a LEFT JOIN profiles p ON p.id=a.profile"
    args = ()
    if pid:
        sql += " WHERE a.profile=?"
        args = (pid,)
    rows = conn.execute(sql + " ORDER BY a.reward_given_at IS NOT NULL, a.id DESC", args).fetchall()
    out = []
    for r in rows:
        a = dict(r)
        keys = json.loads(a["lesson_keys"])
        a["lessons"] = [content.lesson_title(k) for k in keys]
        a["status"] = "given" if a["reward_given_at"] else ("done" if a["done_at"] else "open")
        out.append(a)
    return out


ADJUST_NAMES = {"coins": "خصم عملات", "lesson": "إلغاء درس", "badge": "إلغاء وسام", "sticker": "إلغاء ملصق"}


def adjustments(conn, pid: str) -> list:
    """The parent's decisions for one kid, newest first. Applied once a stored state has them."""
    row = db.kid_state(conn, pid)
    have = set(json.loads(row["data"]).get("adjustments_applied", []) or []) if row else set()
    rows = conn.execute("SELECT * FROM adjustments WHERE profile=? ORDER BY id DESC LIMIT 30", (pid,)).fetchall()
    out = []
    for r in rows:
        a = dict(r)
        a["name"] = ADJUST_NAMES.get(a["kind"], a["kind"])
        a["what"] = ("-%d عملة" % a["amount"]) if a["kind"] == "coins" else a["target"]
        a["applied"] = db.adjustment_key(a["id"]) in have
        out.append(a)
    return out


def lesson_choices(content, s: dict) -> list:
    """Lessons with stars on the kid's phones, for the cancel-a-lesson picker."""
    out = []
    for key, n in (s.get("stars", {}) or {}).items():
        if int(n) > 0 and content.find_lesson(key):
            out.append({"key": key, "title": content.lesson_title(key), "stars": int(n)})
    return sorted(out, key=lambda x: x["title"])


def badge_choices(s: dict) -> list:
    return [{"id": b, "name": BADGES.get(b, b)} for b in s.get("badges", []) or []]


def sticker_choices(content, s: dict) -> list:
    return [{"id": x, "name": content.stickers.get(x, x)} for x in s.get("stickers", []) or []]
