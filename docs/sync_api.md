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
  },
}
```

- `grade` is 1 to 12, or 0 for a toddler (no school books; her games are not sent as rounds).
- `kind` is one of `lesson`, `unit`, `review`, `daily`, `speed`, `assignment`, `family` (one kid's answers
  in a family contest).
- `events` are the rounds finished since the last successful sync. `id` is unique per event; the server
  must ignore an event id it already has (the game resends when a sync fails halfway).
- `assignment` is the assignment id when `kind == "assignment"`, else "".
- `summary` has each kid's whole progress on this phone (coins, xp, stars, badges, stickers, streak, daily,
  review list and so on), plus `changed_at`: the phone's time of the last change to that kid, `""` if the kid
  never changed. **Newest wins:** the server keeps one state per kid and replaces it only when a phone sends
  one whose `changed_at` is later. A kid's coins are not added up across phones.
- `at` is the phone's local time, `YYYY-MM-DDTHH:MM:SS`.

Response (JSON): the full list of open and recently finished assignments, and `kids`: the stored state of each
kid whose stored `changed_at` is later than the one this phone sent (empty when the phone is up to date). The
phone replaces its own state for those kids:

```json
{"ok": true, "assignments": [
  {"id": "a7", "profile": "nada", "title": "اختبار النباتات", "note": "إذا جبت 3 نجوم بنروح على الملاهي",
   "reward": "رحلة للملاهي", "lesson_keys": ["g3_science/u1/l1", "g3_science/u1/l2"],
   "count": 10, "min_stars": 2, "created_at": "2026-10-11T09:00:00",
   "done_at": null, "best_stars": 0}
], "kids": {"nada": {"coins": 70, "xp": 220, "changed_at": "2026-10-12T21:50:00",
  "adjustments_applied": ["j3", "j4"], "...": "the rest of the kid's progress"}}}
```

Adjustments are made by the parent on the dashboard (never by the game):

- `coins`: take `amount` coins **and** the same amount of xp away, never below 0.
- `lesson`: remove the stars of `target` (a lesson key).
- `badge`: take the badge `target` away for good (it is not earned again).
- `sticker`: take the sticker `target` away.

**The server applies them, not the phone.** Each stored kid state carries `adjustments_applied` (the ids it
already includes). When the server stores a state from a phone, or when the parent adds a decision, it applies
every decision the state does not list yet and adds its id. So a newer state from a phone that never saw a
decision still gets it, and a decision is never applied twice. Daily and speed challenges are not cancelled:
they are bound to one day.

An assignment is done when an event with `kind == "assignment"`, `assignment == id` and
`stars >= min_stars` arrives; the server stores `done_at` and `best_stars` (best stars over all tries).
Assignments whose reward the parent marked as given disappear from the response.

## GET /api/ping

Header `X-Device-Key`. Returns `{"ok": true}`; the game's settings screen uses it to test the connection.

## GET /api/app

Header `X-Device-Key`. The newest game version and where to download it:

```json
{"code": 57, "name": "1.57", "url": "https://github.com/karmontal/studygame/releases/download/latest/StudyGame.apk"}
```

- `code` is the Android version code. CI sets it to the build's run number and writes it into the APK's
  `data/build.json`; `0` means unknown (feed unreachable), and a build with code 0 (the editor) never asks.
- The server reads `version.json` from the "latest" release (`STUDYGAME_APP_FEED`) and keeps the answer for
  10 minutes; `STUDYGAME_APK_URL` replaces its `url` with a download address of the parent's own. Only `https://`.
- The game asks on start (when a server is set). If `code` is higher than its own, the profiles screen shows an
  update button that opens `url`. Installing over the old app keeps the progress, because every APK is signed
  with the same key (`tools/android/debug.keystore`).
