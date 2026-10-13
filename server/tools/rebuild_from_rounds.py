"""Rebuild each kid's stored progress from the rounds the server kept (events table).

Use after a phone's fresh install overwrote kid_state: the rounds survive, the whole state does not.
Recovers stars, answered/correct, rounds, wrong-answer review list, coins (as the sum of round coins),
daily and speed records, and the streak. It cannot recover badges, stickers, badges_revoked or the
weekly coins (week resets to 0). Dry run unless --apply is given.

Run inside the dashboard container (back up the database first; see server/README.md):
    docker exec -i studygame-dashboard python - --apply < tools/rebuild_from_rounds.py
Without --apply it only prints what it would store.
"""
import json
import os
import sqlite3
import sys
from collections import Counter
from datetime import date, datetime, timedelta

from app import db  # run from /app inside the container

DB_PATH = os.environ.get("STUDYGAME_DB", "/app/data/studygame.db")


def streaks(days: list[str]) -> tuple[int, int, str]:
    """(current run ending at the last day, best run, last day) for sorted YYYY-MM-DD strings."""
    if not days:
        return 0, 0, ""
    dates = sorted({date.fromisoformat(d) for d in days})
    best = run = 1
    for prev, cur in zip(dates, dates[1:]):
        run = run + 1 if cur - prev == timedelta(days=1) else 1
        best = max(best, run)
    current = 1
    for prev, cur in zip(reversed(dates[:-1]), reversed(dates[1:])):
        if cur - prev == timedelta(days=1):
            current += 1
        else:
            break
    return current, best, dates[-1].isoformat()


def rebuild(conn, pid: str) -> dict:
    events = [dict(r) for r in conn.execute(
        "SELECT * FROM events WHERE profile=? ORDER BY at, received_at", (pid,))]
    stars: dict[str, int] = {}
    review: dict[str, bool] = {}
    for e in events:
        if e["kind"] == "lesson" and e["lesson_key"]:
            stars[e["lesson_key"]] = max(stars.get(e["lesson_key"], 0), e["stars"])
        for key in json.loads(e["wrong"] or "[]"):
            review[key] = True
    coins = sum(e["coins"] for e in events)
    days = [e["at"][:10] for e in events]
    current, best, last = streaks(days)
    dailies = [e for e in events if e["kind"] == "daily"]
    speeds = [e["correct"] for e in events if e["kind"] == "speed"]
    return {
        "stars": stars, "review": review, "badges": {}, "stickers": {}, "badges_revoked": {},
        "answered": sum(e["total"] for e in events), "correct": sum(e["correct"] for e in events),
        "rounds": len(events), "fixed": 0, "coins": coins, "xp": coins,
        "streak": {"days": current, "best": best, "last": last},
        "daily": {"last": max((e["at"][:10] for e in dailies), default=""), "count": len(dailies)},
        "speed_best": max(speeds, default=0), "speed_last": "",
        "week": {"id": 0, "coins": 0},
        "changed_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
    }


def main() -> None:
    apply = "--apply" in sys.argv
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    profiles = [r["id"] for r in conn.execute("SELECT id FROM profiles")]
    for pid in profiles:
        data = rebuild(conn, pid)
        db.apply_adjustments(data, db.kid_adjustments(conn, pid))
        print(pid, "stars:", len(data["stars"]), "rounds:", data["rounds"], "coins:", data["coins"],
              "streak:", data["streak"]["days"], "daily:", data["daily"]["count"])
        if apply:
            conn.execute(
                "INSERT INTO kid_state (profile, data, changed_at, device, updated_at) VALUES (?,?,?,?,?) "
                "ON CONFLICT(profile) DO UPDATE SET data=excluded.data, changed_at=excluded.changed_at, "
                "device=excluded.device, updated_at=excluded.updated_at",
                (pid, json.dumps(data, ensure_ascii=False), data["changed_at"], "rebuild",
                 data["changed_at"]),
            )
    if apply:
        conn.commit()
        print("stored", len(profiles), "kid states")
    else:
        print("dry run: nothing stored (add --apply)")


if __name__ == "__main__":
    main()
