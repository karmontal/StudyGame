import re
import sqlite3

from .conftest import ago, event, sync


def csrf(client, url="/assignments/new?kid=nada&book=g3_science"):
    return re.search(r'name="csrf" value="([^"]+)"', client.get(url).text).group(1)


def test_pages_need_login(client):
    for url in ["/", "/kid/nada", "/kid/nada/week", "/assignments", "/assignments/new"]:
        r = client.get(url, follow_redirects=False)
        assert r.status_code == 303 and r.headers["location"] == "/login", url


def test_wrong_password(client):
    r = client.post("/login", data={"password": "not-the-password"})
    assert "غير صحيحة" in r.text
    assert client.get("/", follow_redirects=False).status_code == 303


def test_login_logout(admin):
    assert admin.get("/").status_code == 200
    admin.post("/logout")
    assert admin.get("/", follow_redirects=False).status_code == 303


def test_pages_render_with_data(admin):
    sync(admin, [event("p1", wrong=["g3_science/u1/l2/0", "g3_science/u1/l2/0"]),
                 event("p2", wrong=["g3_science/u1/l2/0"], at=ago(days=2), stars=1),
                 event("p3", kind="speed", lesson_key="", title="", at=ago(days=20))],
         summary={"nada": {"coins": 320, "xp": 900, "level": 4, "streak": 3, "badges": ["first_round", "perfect"],
                           "stickers": ["lion"], "stars": {"g3_science/u1/l2": 3}, "answered": 40, "correct": 33}})
    home = admin.get("/").text
    for text in ["ندى", "لميس", "مفيد", "لجين", "320", "83%"]:
        assert text in home
    kid = admin.get("/kid/nada").text
    question = "كل البذور لها نفس الشكل واللون والحجم."
    for text in ["العلوم والحياة", "البذور", "علامة كاملة", "الأسد الخرّيج", question, "الإجابة: خطأ", "3 مرات", "تحدي السرعة"]:
        assert text in kid, text
    week = admin.get("/kid/nada/week").text
    assert "تقرير الأسبوع" in week and "البذور" in week and "جديد" in week
    assert admin.get("/kid/lamees").status_code == 200
    assert admin.get("/kid/lamees/week").status_code == 200
    assert admin.get("/assignments").status_code == 200


def test_empty_kid_pages(admin):
    assert "لم يلعب بعد" in admin.get("/").text
    assert admin.get("/kid/nobody", follow_redirects=False).status_code == 303


def test_create_reward_delete_assignment(admin, settings):
    page = admin.get("/assignments/new?kid=nada").text
    assert "العلوم والحياة" in page and "g10_" not in page
    page = admin.get("/assignments/new?kid=nada&book=g3_science").text
    assert 'value="g3_science/u1/l1"' in page
    token = csrf(admin)
    form = {"csrf": token, "kid": "nada", "book": "g3_science", "lessons": ["g3_science/u1/l1", "g3_science/u1/l2"],
            "title": "اختبار النباتات", "note": "بالتوفيق", "reward": "رحلة للملاهي", "min_stars": "2", "count": "10"}
    r = admin.post("/assignments", data=form)
    assert r.status_code == 200 and "اختبار النباتات" in r.text and "رحلة للملاهي" in r.text
    a = sync(admin).json()["assignments"][0]
    assert a["lesson_keys"] == ["g3_science/u1/l1", "g3_science/u1/l2"] and a["min_stars"] == 2
    num = int(a["id"][1:])

    sync(admin, [event("as1", kind="assignment", assignment=a["id"], stars=3)])
    assert "سلّمت الجائزة" in admin.get("/assignments").text
    admin.post(f"/assignments/{num}/reward", data={"csrf": token})
    assert sync(admin).json()["assignments"] == []
    assert "تم تسليم الجائزة" in admin.get("/assignments").text

    admin.post(f"/assignments/{num}/delete", data={"csrf": token})
    conn = sqlite3.connect(settings.db_path)
    assert conn.execute("SELECT COUNT(*) FROM assignments").fetchone()[0] == 0
    conn.close()


def test_assignment_validation(admin, settings):
    token = csrf(admin)
    base = {"csrf": token, "kid": "nada", "book": "g3_science", "lessons": ["g3_science/u1/l1"],
            "min_stars": "2", "count": "10"}
    bad = [
        {**base, "lessons": []},
        {**base, "count": "25"},
        {**base, "min_stars": "0"},
        {**base, "book": "g10_math", "lessons": ["g10_math/u1/l1"]},  # not nada's grade
        {**base, "lessons": ["g3_science/u1/l999"]},
        {**base, "csrf": "forged"},
    ]
    for form in bad:
        admin.post("/assignments", data=form)
    conn = sqlite3.connect(settings.db_path)
    assert conn.execute("SELECT COUNT(*) FROM assignments").fetchone()[0] == 0
    conn.close()


def test_post_needs_csrf(admin, settings):
    token = csrf(admin)
    admin.post("/assignments", data={"csrf": token, "kid": "nada", "book": "g3_science",
                                     "lessons": ["g3_science/u1/l1"], "min_stars": "2", "count": "10"})
    admin.post("/assignments/1/delete", data={"csrf": "wrong"})
    conn = sqlite3.connect(settings.db_path)
    assert conn.execute("SELECT COUNT(*) FROM assignments").fetchone()[0] == 1
    conn.close()


def test_weekly_report_counts_last_7_days(admin, settings):
    from app import db, stats
    from app.content import Content
    sync(admin, [event("w1", correct=6, total=8), event("w2", at=ago(days=3), stars=2, correct=4, total=8),
                 event("w3", at=ago(days=9))])
    with db.connect(settings.db_path) as conn:
        r = stats.weekly(conn, Content(settings.content_dir), "nada")
    assert r["rounds"] == 2 and r["answered"] == 16 and r["accuracy"] == 63 and r["stars"] == 5
    assert r["new_lessons"] == 0  # the lesson was first played 9 days ago
    assert sum(d["rounds"] for d in r["days"]) == 2


def test_toddler_profile(admin):
    body = {"device": "android-test", "profiles": [{"id": "aya", "name": "آية", "grade": 0}], "events": [],
            "summary": {}}
    assert admin.post("/api/sync", json=body, headers={"X-Device-Key": "test-device-key"}).status_code == 200
    home = admin.get("/").text
    assert "آية" in home and "ألعاب الصغار" in home and "الصف 0" not in home
    assert admin.get("/kid/aya").status_code == 200
    assert admin.get("/kid/aya/week").status_code == 200
    assert admin.get("/assignments/new?kid=aya").status_code == 200
