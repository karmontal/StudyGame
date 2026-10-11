import os
import sys
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

KEY = "test-device-key"
PASSWORD = "test-password"
CONTENT = os.path.join(os.path.dirname(__file__), "..", "..", "data")


@pytest.fixture
def settings(tmp_path):
    return Settings(device_key=KEY, admin_password=PASSWORD, db_path=str(tmp_path / "db" / "t.db"),
                    content_dir=CONTENT)


@pytest.fixture
def client(settings):
    with TestClient(create_app(settings)) as c:
        yield c


@pytest.fixture
def admin(client):
    r = client.post("/login", data={"password": PASSWORD})
    assert r.status_code == 200 and "الأولاد" in r.text
    return client



def ago(hours=0, days=0) -> str:
    return (datetime.now() - timedelta(hours=hours, days=days)).strftime("%Y-%m-%dT%H:%M:%S")


def event(eid, **kw):
    e = {"id": eid, "profile": "nada", "kind": "lesson", "lesson_key": "g3_science/u1/l2", "book": "g3_science",
         "unit": "u1", "title": "البذور", "stars": 3, "correct": 8, "total": 8, "coins": 145, "assignment": "",
         "wrong": [], "at": ago(hours=1)}
    e.update(kw)
    return e


def sync(client, events=(), summary=None, key=KEY):
    body = {"device": "android-test", "profiles": [{"id": "nada", "name": "ندى", "grade": 3}],
            "events": list(events), "summary": summary or {}}
    return client.post("/api/sync", json=body, headers={"X-Device-Key": key})
