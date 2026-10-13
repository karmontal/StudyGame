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
-- One state per kid: the phone's whole progress, kept only if its changed_at is newer than what is stored.
CREATE TABLE IF NOT EXISTS kid_state (
    profile TEXT PRIMARY KEY, data TEXT NOT NULL, changed_at TEXT NOT NULL, device TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT, profile TEXT NOT NULL, title TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '', reward TEXT NOT NULL DEFAULT '', lesson_keys TEXT NOT NULL,
    count INTEGER NOT NULL, min_stars INTEGER NOT NULL, created_at TEXT NOT NULL,
    done_at TEXT, best_stars INTEGER NOT NULL DEFAULT 0, reward_given_at TEXT
);
-- Parent decisions (coins taken away, lesson/badge/sticker cancelled). The server applies them to each
-- stored kid state that does not have them yet (see apply_adjustments); phones never apply them.
CREATE TABLE IF NOT EXISTS adjustments (
    id INTEGER PRIMARY KEY AUTOINCREMENT, profile TEXT NOT NULL, kind TEXT NOT NULL,
    target TEXT NOT NULL DEFAULT '', amount INTEGER NOT NULL DEFAULT 0, reason TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL
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
    raw.close()
    with connect(path) as conn:
        for p in default_profiles:
            conn.execute(
                "INSERT OR IGNORE INTO profiles (id, name, grade, color, updated_at) VALUES (?,?,?,?,?)",
                (p["id"], p["name"], int(p["grade"]), p.get("color", ""), now_str()),
            )


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
    # Newest wins: a phone's state replaces the stored one only if it was changed later. Parent decisions
    # the phone's state does not have yet are applied to it first, so a newer state can't undo them.
    for profile, sent in req.summary.items():
        changed = str(sent.get("changed_at", ""))
        stored = kid_state(conn, profile)
        if not changed or (stored and not changed > stored["changed_at"]):
            continue
        data = dict(sent)
        apply_adjustments(data, kid_adjustments(conn, profile))
        conn.execute(
            "INSERT INTO kid_state (profile, data, changed_at, device, updated_at) VALUES (?,?,?,?,?) "
            "ON CONFLICT(profile) DO UPDATE SET data=excluded.data, changed_at=excluded.changed_at, "
            "device=excluded.device, updated_at=excluded.updated_at",
            (profile, json.dumps(data, ensure_ascii=False), changed, req.device, now),
        )


def kid_state(conn, profile: str):
    row = conn.execute("SELECT * FROM kid_state WHERE profile=?", (profile,)).fetchone()
    return dict(row) if row else None


def newer_kid_states(conn, sent: dict) -> dict:
    """Stored states that are newer than the changed_at a phone sent for that kid (kid -> changed_at)."""
    out = {}
    for profile, changed in sent.items():
        row = kid_state(conn, profile)
        if row and row["changed_at"] > changed:
            out[profile] = json.loads(row["data"])
    return out


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


# ---------- parent adjustments (coins taken away, lessons/badges/stickers cancelled) ----------

def adjustment_key(row_id) -> str:
    return f"j{row_id}"


def kid_adjustments(conn, profile: str) -> list:
    rows = conn.execute("SELECT * FROM adjustments WHERE profile=? ORDER BY id", (profile,)).fetchall()
    return [dict(r) for r in rows]


def apply_adjustments(data: dict, adjustments: list) -> bool:
    """Applies the parent's decisions that `data` does not have yet (its adjustments_applied list).
    Returns True when something changed. Coins and xp never go below 0."""
    done = list(data.get("adjustments_applied", []) or [])
    changed = False
    for a in adjustments:
        key = adjustment_key(a["id"])
        if key in done:
            continue
        done.append(key)
        changed = True
        target = a["target"]
        if a["kind"] == "coins":
            data["coins"] = max(0, int(data.get("coins", 0) or 0) - a["amount"])
            data["xp"] = max(0, int(data.get("xp", 0) or 0) - a["amount"])
        elif a["kind"] == "lesson":
            (data.setdefault("stars", {}) or {}).pop(target, None)
        elif a["kind"] == "badge":
            data.setdefault("badges", {}).pop(target, None)
            data.setdefault("badges_revoked", {})[target] = True
        elif a["kind"] == "sticker":
            data.setdefault("stickers", {}).pop(target, None)
    if changed:
        data["adjustments_applied"] = done
    return changed


def reapply_stored(conn, profile: str) -> None:
    """After the parent adds a decision: apply it to the stored state now and mark that state as newer,
    so the phones take it on their next sync."""
    row = kid_state(conn, profile)
    if not row:
        return  # no state yet: the first phone that sends one gets the decisions when it is stored
    data = json.loads(row["data"])
    if apply_adjustments(data, kid_adjustments(conn, profile)):
        now = now_str()
        conn.execute("UPDATE kid_state SET data=?, changed_at=?, updated_at=? WHERE profile=?",
                     (json.dumps(data, ensure_ascii=False), now, now, profile))
