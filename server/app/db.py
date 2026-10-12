"""SQLite storage (stdlib sqlite3, no ORM)."""
import json
import os
import sqlite3
from contextlib import contextmanager
from datetime import datetime

SCHEMA = """
CREATE TABLE IF NOT EXISTS profiles (
    id TEXT PRIMARY KEY, name TEXT NOT NULL, grade INTEGER NOT NULL,
    color TEXT NOT NULL DEFAULT '', updated_at TEXT
);
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY, profile TEXT NOT NULL, kind TEXT NOT NULL,
    lesson_key TEXT NOT NULL DEFAULT '', book TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL DEFAULT '', stars INTEGER NOT NULL DEFAULT 0, correct INTEGER NOT NULL DEFAULT 0,
    total INTEGER NOT NULL DEFAULT 0, coins INTEGER NOT NULL DEFAULT 0,
    assignment TEXT NOT NULL DEFAULT '', wrong TEXT NOT NULL DEFAULT '[]',
    at TEXT NOT NULL, device TEXT NOT NULL DEFAULT '', received_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS events_profile_at ON events(profile, at);
CREATE TABLE IF NOT EXISTS device_summaries (
    profile TEXT NOT NULL, device TEXT NOT NULL, data TEXT NOT NULL, updated_at TEXT NOT NULL,
    PRIMARY KEY (profile, device)
);
CREATE TABLE IF NOT EXISTS assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT, profile TEXT NOT NULL, title TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '', reward TEXT NOT NULL DEFAULT '', lesson_keys TEXT NOT NULL,
    count INTEGER NOT NULL, min_stars INTEGER NOT NULL, created_at TEXT NOT NULL,
    done_at TEXT, best_stars INTEGER NOT NULL DEFAULT 0, reward_given_at TEXT
);
"""


def now_str() -> str:
    """Server local time in the same format the game uses for `at`."""
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def init(path: str, default_profiles: list) -> None:
    folder = os.path.dirname(os.path.abspath(path))
    os.makedirs(folder, exist_ok=True)
    raw = sqlite3.connect(path)
    raw.executescript(SCHEMA)  # runs outside connect(): executescript commits on its own
    _migrate(raw)
    raw.close()
    with connect(path) as conn:
        for p in default_profiles:
            conn.execute(
                "INSERT OR IGNORE INTO profiles (id, name, grade, color, updated_at) VALUES (?,?,?,?,?)",
                (p["id"], p["name"], int(p["grade"]), p.get("color", ""), now_str()),
            )


def _migrate(raw) -> None:
    """Version 1 kept one summary per kid, so each device overwrote the others; keep them per device now."""
    if raw.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='summaries'").fetchone():
        with raw:
            raw.execute("INSERT OR IGNORE INTO device_summaries (profile, device, data, updated_at) "
                        "SELECT profile, device, data, updated_at FROM summaries")
            raw.execute("DROP TABLE summaries")


@contextmanager
def connect(path: str):
    conn = sqlite3.connect(path, timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    try:
        conn.execute("BEGIN IMMEDIATE")
        yield conn
        conn.execute("COMMIT")
    except BaseException:
        if conn.in_transaction:
            conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()


# ---------- assignments ----------

def assignment_public(row) -> dict:
    """Assignment in the exact shape of docs/sync_api.md."""
    return {
        "id": f"a{row['id']}",
        "profile": row["profile"],
        "title": row["title"],
        "note": row["note"],
        "reward": row["reward"],
        "lesson_keys": json.loads(row["lesson_keys"]),
        "count": row["count"],
        "min_stars": row["min_stars"],
        "created_at": row["created_at"],
        "done_at": row["done_at"],
        "best_stars": row["best_stars"],
    }


def parse_assignment_id(text: str):
    if text.startswith("a") and text[1:].isdigit():
        return int(text[1:])
    return None


def pending_assignments(conn) -> list:
    rows = conn.execute("SELECT * FROM assignments WHERE reward_given_at IS NULL ORDER BY id").fetchall()
    return [assignment_public(r) for r in rows]


# ---------- sync ----------

def apply_sync(conn, req) -> None:
    """Store one /api/sync request. Events already stored (same id) are ignored entirely."""
    now = now_str()
    for p in req.profiles:
        conn.execute(
            "INSERT INTO profiles (id, name, grade, updated_at) VALUES (?,?,?,?) "
            "ON CONFLICT(id) DO UPDATE SET name=excluded.name, grade=excluded.grade, updated_at=excluded.updated_at",
            (p.id, p.name, p.grade, now),
        )
    for e in req.events:
        cur = conn.execute(
            "INSERT OR IGNORE INTO events (id, profile, kind, lesson_key, book, unit, title, stars, correct, total,"
            " coins, assignment, wrong, at, device, received_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (e.id, e.profile, e.kind, e.lesson_key, e.book, e.unit, e.title, e.stars, e.correct, e.total,
             e.coins, e.assignment, json.dumps(e.wrong), e.at, req.device, now),
        )
        if cur.rowcount == 1 and e.kind == "assignment":
            _apply_assignment_try(conn, e)
    for profile, data in req.summary.items():
        conn.execute(
            "INSERT INTO device_summaries (profile, device, data, updated_at) VALUES (?,?,?,?) "
            "ON CONFLICT(profile, device) DO UPDATE SET data=excluded.data, updated_at=excluded.updated_at",
            (profile, req.device, json.dumps(data, ensure_ascii=False), now),
        )


def _apply_assignment_try(conn, e) -> None:
    aid = parse_assignment_id(e.assignment)
    if aid is None:
        return
    row = conn.execute("SELECT * FROM assignments WHERE id=?", (aid,)).fetchone()
    if row is None:
        return
    best = max(row["best_stars"], e.stars)
    done_at = row["done_at"]
    if done_at is None and e.stars >= row["min_stars"]:
        done_at = e.at
    conn.execute("UPDATE assignments SET best_stars=?, done_at=? WHERE id=?", (best, done_at, aid))
