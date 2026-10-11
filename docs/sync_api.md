# Parent dashboard sync API

The game (Android) talks to a small server the parent runs (`server/`). The game works fully offline;
when a server is set in its parent settings it uploads progress and downloads assignments.

Auth: every `/api/*` request carries the header `X-Device-Key: <key>` (the server's `STUDYGAME_DEVICE_KEY`).
The dashboard itself (`/`) is protected by `STUDYGAME_ADMIN_PASSWORD` (login form, session cookie).

## POST /api/sync

Request body (JSON):

```json
{
  "device": "android-1b2c",
  "profiles": [{"id": "lamees", "name": "لميس", "grade": 10}],
  "events": [
    {"id": "e-1728640000-123", "profile": "nada", "kind": "lesson",
     "lesson_key": "g3_science/u1/l2", "book": "g3_science", "unit": "u1", "title": "البذور",
     "stars": 3, "correct": 8, "total": 8, "coins": 145, "assignment": "",
     "wrong": ["g3_science/u1/l2/4"], "at": "2026-10-11T08:30:00"}
  ],
  "summary": {
    "nada": {"coins": 320, "xp": 900, "level": 4, "streak": 3, "speed_best": 12,
             "badges": ["first_round", "perfect"], "stickers": ["lion"],
             "stars": {"g3_science/u1/l2": 3}, "answered": 40, "correct": 33}
  }
}
```

- `grade` is 1 to 12, or 0 for a toddler (no school books; her games are not sent as rounds).
- `kind` is one of `lesson`, `unit`, `review`, `daily`, `speed`, `assignment`, `family` (one kid's answers
  in a family contest).
- `events` are the rounds finished since the last successful sync. `id` is unique per event; the server
  must ignore an event id it already has (the game resends when a sync fails halfway).
- `assignment` is the assignment id when `kind == "assignment"`, else "".
- `summary` is the full current state per kid (replaces the previous one).
- `at` is the phone's local time, `YYYY-MM-DDTHH:MM:SS`.

Response (JSON), always the full list of open and recently finished assignments:

```json
{"ok": true, "assignments": [
  {"id": "a7", "profile": "nada", "title": "اختبار النباتات", "note": "إذا جبت 3 نجوم بنروح على الملاهي",
   "reward": "رحلة للملاهي", "lesson_keys": ["g3_science/u1/l1", "g3_science/u1/l2"],
   "count": 10, "min_stars": 2, "created_at": "2026-10-11T09:00:00",
   "done_at": null, "best_stars": 0}
]}
```

An assignment is done when an event with `kind == "assignment"`, `assignment == id` and
`stars >= min_stars` arrives; the server stores `done_at` and `best_stars` (best stars over all tries).
Assignments whose reward the parent marked as given disappear from the response.

## GET /api/ping

Header `X-Device-Key`. Returns `{"ok": true}`; the game's settings screen uses it to test the connection.
