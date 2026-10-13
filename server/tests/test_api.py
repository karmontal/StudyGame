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
    assert r.status_code == 200 and r.json() == {"ok": True, "assignments": [], "kids": {}}
    r = sync(client, [event("e1", stars=0, title="changed"), event("e3")])
    assert r.status_code == 200
    got = dict(rows(settings, "SELECT id, title FROM events"))
    assert set(got) == {"e1", "e2", "e3"} and got["e1"] == "البذور"


def test_duplicate_ids_in_one_request(client, settings):
    assert sync(client, [event("e1"), event("e1")]).status_code == 200
    assert rows(settings, "SELECT COUNT(*) FROM events")[0][0] == 1


def test_newest_state_wins(client, settings):
    sync(client, summary={"nada": {"coins": 10, "changed_at": "2026-10-12T10:00:00", "badges": {"first_round": True}}})
    sync(client, summary={"nada": {"coins": 5, "changed_at": "2026-10-12T09:00:00"}})  # older: ignored
    sync(client, summary={"nada": {"coins": 320, "changed_at": "2026-10-12T11:00:00"}})
    data = json.loads(rows(settings, "SELECT data FROM kid_state WHERE profile='nada'")[0][0])
    assert data["coins"] == 320
    # A phone with no change yet (no changed_at) never overwrites a stored state.
    sync(client, summary={"nada": {"coins": 0}})
    assert json.loads(rows(settings, "SELECT data FROM kid_state WHERE profile='nada'")[0][0])["coins"] == 320


def test_phone_gets_the_newer_stored_state(client):
    sync(client, summary={"nada": {"coins": 320, "changed_at": "2026-10-12T11:00:00", "stars": {}}})
    body = {"device": "phone-b", "profiles": [{"id": "nada", "name": "ندى", "grade": 3}], "events": [],
            "summary": {"nada": {"coins": 5, "changed_at": "2026-10-12T09:00:00"}}}
    got = client.post("/api/sync", json=body, headers={"X-Device-Key": KEY}).json()["kids"]
    assert got["nada"]["coins"] == 320
    body["summary"]["nada"]["changed_at"] = "2026-10-12T11:00:00"  # same state: nothing to send back
    assert client.post("/api/sync", json=body, headers={"X-Device-Key": KEY}).json()["kids"] == {}


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


def add_adjustment(admin, kind, target="", amount=0, pid="nada"):
    token = admin.get(f"/kid/{pid}").text.split('name="csrf" value="')[1].split('"')[0]
    r = admin.post(f"/kid/{pid}/adjust", data={"csrf": token, "kind": kind, "target": target,
                                              "amount": amount, "reason": "تجربة"}, follow_redirects=False)
    assert r.status_code == 303


def push(client, device, state, pid="nada"):
    """A phone sends the whole state of one kid; returns the kids the server sent back."""
    body = {"device": device, "profiles": [{"id": pid, "name": pid, "grade": 3}], "events": [],
            "summary": {pid: state}}
    r = client.post("/api/sync", json=body, headers={"X-Device-Key": KEY})
    assert r.status_code == 200, r.text
    return r.json()["kids"]


def stored(settings, pid="nada"):
    return json.loads(rows(settings, "SELECT data FROM kid_state WHERE profile=?", pid)[0][0])


def test_deduction_is_applied_to_the_stored_state(client, admin, settings):
    push(client, "phone-a", {"coins": 100, "xp": 250, "changed_at": "2026-10-12T10:00:00"})
    add_adjustment(admin, "coins", amount=30)
    got = push(client, "phone-b", {"coins": 0, "changed_at": "2026-10-12T09:00:00"})  # phone-b is older
    assert got["nada"]["coins"] == 70 and got["nada"]["xp"] == 220
    assert got["nada"]["adjustments_applied"] == ["j1"]


def test_newer_phone_state_that_lacks_a_deduction_still_gets_it(client, admin, settings):
    # The race: phone-a applied the deduction, then phone-b sent a newer state without it.
    push(client, "phone-a", {"coins": 100, "changed_at": "2026-10-12T10:00:00"})
    add_adjustment(admin, "coins", amount=30)
    # phone-b changed its state after the server stored the deduction (server time is later than phone time).
    push(client, "phone-b", {"coins": 90, "changed_at": "2099-01-01T00:00:00"})
    assert stored(settings)["coins"] == 60
    # The same decision is never applied twice, even when the phone sends it back.
    push(client, "phone-b", {"coins": 60, "changed_at": "2099-01-02T00:00:00", "adjustments_applied": ["j1"]})
    assert stored(settings)["coins"] == 60


def test_deduction_made_before_any_state_applies_to_the_first_one(client, admin, settings):
    add_adjustment(admin, "coins", amount=20)
    push(client, "phone-a", {"coins": 100, "changed_at": "2026-10-12T10:00:00"})
    assert stored(settings)["coins"] == 80


def test_cancelled_lesson_badge_and_sticker_stay_cancelled(client, admin, settings):
    push(client, "phone-a", {"coins": 0, "stars": {"g3_science/u1/l2": 3}, "badges": {"perfect": True},
                             "stickers": {"lion": True}, "changed_at": "2026-10-12T10:00:00"})
    add_adjustment(admin, "lesson", target="g3_science/u1/l2")
    add_adjustment(admin, "badge", target="perfect")
    add_adjustment(admin, "sticker", target="lion")
    # A phone that still has all three sends a newer state.
    push(client, "phone-b", {"coins": 0, "stars": {"g3_science/u1/l2": 3}, "badges": {"perfect": True},
                             "stickers": {"lion": True}, "changed_at": "2026-10-12T11:00:00"})
    s = stored(settings)
    assert s["stars"] == {} and s["badges"] == {} and s["stickers"] == {}
    assert s["badges_revoked"] == {"perfect": True}


def test_adjustment_form_validates(admin):
    add_adjustment(admin, "coins", amount=9999)
    add_adjustment(admin, "lesson", target="nope/u1/l1")
    add_adjustment(admin, "badge", target="not_a_badge")
    add_adjustment(admin, "sticker", target="not_a_sticker")
    assert "ما انحفظ" in admin.get("/kid/nada?error=amount").text
    assert "-9999" not in admin.get("/kid/nada").text  # nothing stored


def test_adjustment_shows_on_dashboard(client, admin):
    push(client, "phone-a", {"coins": 50, "changed_at": "2026-10-12T10:00:00"})
    add_adjustment(admin, "coins", amount=20)
    page = admin.get("/kid/nada").text
    assert "خصم عملات" in page and "-20 عملة" in page and "اتطبّق" in page
    assert "30" in admin.get("/kid/nada").text  # the coins shown are already the new total
