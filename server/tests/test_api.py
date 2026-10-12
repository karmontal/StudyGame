import json
import sqlite3

from .conftest import KEY, ago, event, sync


def rows(settings, sql, *args):
    conn = sqlite3.connect(settings.db_path)
    try:
        return conn.execute(sql, args).fetchall()
    finally:
        conn.close()


def add_assignment(settings, min_stars=2, profile="nada"):
    conn = sqlite3.connect(settings.db_path)
    cur = conn.execute(
        "INSERT INTO assignments (profile, title, note, reward, lesson_keys, count, min_stars, created_at)"
        " VALUES (?,?,?,?,?,?,?,?)",
        (profile, "اختبار النباتات", "بالتوفيق", "رحلة", json.dumps(["g3_science/u1/l1"]), 10, min_stars, ago()))
    conn.commit()
    conn.close()
    return f"a{cur.lastrowid}"


def test_ping_requires_key(client):
    assert client.get("/api/ping").status_code == 401
    assert client.get("/api/ping", headers={"X-Device-Key": "wrong-key-123"}).status_code == 401
    r = client.get("/api/ping", headers={"X-Device-Key": KEY})
    assert r.status_code == 200 and r.json() == {"ok": True}


def test_sync_wrong_key_401(client, settings):
    assert sync(client, [event("e1")], key="nope-nope-nope").status_code == 401
    assert rows(settings, "SELECT COUNT(*) FROM events")[0][0] == 0


def test_sync_is_idempotent(client, settings):
    r = sync(client, [event("e1"), event("e2", stars=1)])
    assert r.status_code == 200 and r.json() == {"ok": True, "assignments": []}
    r = sync(client, [event("e1", stars=0, title="changed"), event("e3")])
    assert r.status_code == 200
    got = dict(rows(settings, "SELECT id, title FROM events"))
    assert set(got) == {"e1", "e2", "e3"} and got["e1"] == "البذور"


def test_duplicate_ids_in_one_request(client, settings):
    assert sync(client, [event("e1"), event("e1")]).status_code == 200
    assert rows(settings, "SELECT COUNT(*) FROM events")[0][0] == 1


def test_summary_replaces_previous(client, settings):  # same device: its summary is replaced
    sync(client, summary={"nada": {"coins": 10, "level": 1, "badges": ["first_round"]}})
    sync(client, summary={"nada": {"coins": 320, "level": 4}})
    data = json.loads(rows(settings, "SELECT data FROM device_summaries WHERE profile='nada'")[0][0])
    assert data == {"coins": 320, "level": 4}


def test_assignment_completion(client, settings):
    aid = add_assignment(settings, min_stars=2)
    other = add_assignment(settings, min_stars=1)
    # A try below min_stars: best_stars updates, not done.
    r = sync(client, [event("t1", kind="assignment", assignment=aid, stars=1)])
    a = {x["id"]: x for x in r.json()["assignments"]}[aid]
    assert a["done_at"] is None and a["best_stars"] == 1
    # A non-assignment event with enough stars does not count.
    r = sync(client, [event("t2", kind="lesson", assignment=aid, stars=3)])
    assert {x["id"]: x for x in r.json()["assignments"]}[aid]["done_at"] is None
    # Enough stars: done.
    at = ago()
    r = sync(client, [event("t3", kind="assignment", assignment=aid, stars=2, at=at)])
    a = {x["id"]: x for x in r.json()["assignments"]}[aid]
    assert a["done_at"] == at and a["best_stars"] == 2
    # Later tries keep done_at, raise best_stars only upwards.
    r = sync(client, [event("t4", kind="assignment", assignment=aid, stars=3, at=ago(hours=-1)),
                      event("t5", kind="assignment", assignment=aid, stars=1)])
    a = {x["id"]: x for x in r.json()["assignments"]}[aid]
    assert a["done_at"] == at and a["best_stars"] == 3
    # The other assignment is untouched; shape matches the contract.
    o = {x["id"]: x for x in r.json()["assignments"]}[other]
    assert o == {"id": other, "profile": "nada", "title": "اختبار النباتات", "note": "بالتوفيق", "reward": "رحلة",
                 "lesson_keys": ["g3_science/u1/l1"], "count": 10, "min_stars": 1, "created_at": o["created_at"],
                 "done_at": None, "best_stars": 0}


def test_resent_assignment_event_not_reprocessed(client, settings):
    aid = add_assignment(settings, min_stars=3)
    sync(client, [event("x1", kind="assignment", assignment=aid, stars=1)])
    conn = sqlite3.connect(settings.db_path)
    conn.execute("UPDATE assignments SET best_stars=0")
    conn.commit()
    conn.close()
    r = sync(client, [event("x1", kind="assignment", assignment=aid, stars=1)])
    assert r.json()["assignments"][0]["best_stars"] == 0


def test_reward_given_disappears(client, settings):
    aid = add_assignment(settings, min_stars=1)
    sync(client, [event("d1", kind="assignment", assignment=aid, stars=1)])
    conn = sqlite3.connect(settings.db_path)
    conn.execute("UPDATE assignments SET reward_given_at=?", (ago(),))
    conn.commit()
    conn.close()
    assert sync(client).json()["assignments"] == []


def test_body_too_large(client):
    big = {"device": "x" * (1024 * 1024 + 10)}
    r = client.post("/api/sync", content=json.dumps(big), headers={"X-Device-Key": KEY,
                                                                    "Content-Type": "application/json"})
    assert r.status_code == 413


def test_too_many_events(client, settings):
    r = sync(client, [event(f"m{i}") for i in range(501)])
    assert r.status_code == 422
    assert rows(settings, "SELECT COUNT(*) FROM events")[0][0] == 0
    assert sync(client, [event(f"m{i}") for i in range(500)]).status_code == 200


def test_invalid_input(client):
    assert sync(client, [event("b1", kind="bogus")]).status_code == 422
    assert sync(client, [event("b2", stars=4)]).status_code == 422
    assert sync(client, [event("b3", at="yesterday")]).status_code == 422
    r = client.post("/api/sync", content=b"{not json", headers={"X-Device-Key": KEY})
    assert r.status_code == 422


def test_summaries_from_two_devices_add_up(client, settings):
    def send(device, summary):
        body = {"device": device, "profiles": [{"id": "nada", "name": "ندى", "grade": 3}], "events": [],
                "summary": summary}
        assert client.post("/api/sync", json=body, headers={"X-Device-Key": KEY}).status_code == 200

    send("phone-a", {"nada": {"coins": 100, "xp": 250, "answered": 10, "correct": 8, "streak": 2,
                              "badges": ["first_round"], "stickers": [], "stars": {"g3_science/u1/l1": 3}}})
    send("phone-b", {"nada": {"coins": 50, "xp": 100, "answered": 5, "correct": 5, "streak": 4,
                              "badges": ["first_round", "perfect"], "stickers": ["lion"],
                              "stars": {"g3_science/u1/l1": 1, "g3_science/u1/l2": 2}}})
    # A phone where Nada never played must not wipe her numbers.
    send("phone-c", {"nada": {"coins": 0, "xp": 0, "answered": 0, "correct": 0, "stars": {}}})
    from app import db, stats
    with db.connect(settings.db_path) as conn:
        s = stats.summary(conn, "nada")
    assert s["coins"] == 150 and s["answered"] == 15 and s["correct"] == 13
    assert s["level"] == 2 and s["streak"] == 4
    assert s["badges"] == ["first_round", "perfect"] and s["stickers"] == ["lion"]
    assert s["stars"] == {"g3_science/u1/l1": 3, "g3_science/u1/l2": 2}
    # The same phone syncing again replaces its own numbers, it doesn't add them twice.
    send("phone-a", {"nada": {"coins": 120, "xp": 270, "answered": 12, "correct": 9, "stars": {}}})
    with db.connect(settings.db_path) as conn:
        assert stats.summary(conn, "nada")["coins"] == 170


def test_old_single_summary_table_is_migrated(tmp_path):
    import json as _json
    import sqlite3
    from app import db, stats
    path = str(tmp_path / "old.db")
    raw = sqlite3.connect(path)
    raw.execute("CREATE TABLE summaries (profile TEXT PRIMARY KEY, data TEXT NOT NULL, "
                "device TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)")
    raw.execute("INSERT INTO summaries VALUES (?,?,?,?)",
                ("nada", _json.dumps({"coins": 42, "xp": 0, "answered": 3}), "phone-a", "2026-10-11T10:00:00"))
    raw.commit()
    raw.close()
    db.init(path, [])
    with db.connect(path) as conn:
        assert stats.summary(conn, "nada")["coins"] == 42
        assert not conn.execute("SELECT name FROM sqlite_master WHERE name='summaries'").fetchone()
