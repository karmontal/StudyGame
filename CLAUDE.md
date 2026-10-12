# StudyGame — notes for Claude

- Kids' quiz game from school-book PDFs (`Books/`, Palestinian 2024 "رزمة تعليمية" packets for Gaza).
  Players: Lamees grade 10, Mufeed grade 8, Lujain grade 5, Nada grade 3, Aya age 2 (`data/profiles_default.json`).
  Subjects are in `data/subjects.json` (including `islamic`); books are listed in `data/books/index.json`.
- Godot 4.7, GDScript, portrait 1080×1920, Arabic RTL UI with the Cairo font (no emoji/★ glyphs:
  stars are drawn by `StarRow`).
- Content: never hand-edit `data/books/*.json`; edit `tools/content/<book>.py` (helpers in `common.py`)
  and re-run it. Questions must come from the book's lesson, short and age-appropriate.
  `Content.validate_book()` is the schema; the tests run it on every book. `python3 tools/content/validate.py`
  applies the same rules without Godot.
- Motivation system: `scripts/game/rewards.gd` (coins, levels, badges: pure rules) and
  `Profiles.finish_round()` (applies them: coins, daily streak, daily challenge, speed best, weekly board).
  Every finished round must go through `finish_round()`. Stickers for the album are in `data/stickers.json`.
- Node names inside a screen must be unique (tests find buttons by name); clear containers with
  `remove_child` before rebuilding.
- Before pushing run: `godot --headless --path . --import` then
  `godot --headless --path . res://tests/test_runner.tscn` (must exit 0).
- Android APK is built in CI (`.github/workflows/android.yml`); the cloud container cannot reach the
  Android SDK or the Higgsfield CDN.
- Sound: `Sfx` autoload plays `assets/sfx/*.wav` (made by `tools/make_sfx.py`) and reads questions aloud with
  the phone's TTS (`Sfx.speak`). `Settings` (user://settings.cfg) holds the sound switch and dashboard address.
- Parent dashboard: `server/` (FastAPI + SQLite, `cd server && pytest -q`). Game side is the `Sync` autoload;
  `Profiles.finish_round()` queues every round. The contract is `docs/sync_api.md`; change both sides together.
- Toddler section (Aya, age 2): `scripts/toddler/` (hub screen "toddler", games `toddler_*`, rest screen after
  10 min). Nothing to read, no losing/timers/coins; parents leave with a 1.5 s long press (`ToddlerHold`).
  Shapes are drawn by `ToddlerArt`; voice goes through `ToddlerVoice.say(key)`, which plays
  `assets/toddler/voice/<key>.ogg|.mp3|.wav` when recorded, else the phone's TTS (keys in `ToddlerVoice.PHRASES`).
  After changing PHRASES run `python3 tools/aya_voice_list.py` (regenerates `docs/aya_voice.md` for Karam).
- Dashboard summaries are stored per device and merged per kid (`server/app/stats.py merge_summaries`);
  a phone only sends summaries for kids who played on it.
- Family contest (gatherings): rules in `scripts/game/family_contest.gd` (turn order, teams, one point per right
  answer, each kid's questions from their own grade, picture questions for the toddler); screens "family" and
  "family_play". Each school kid's answers go through `finish_round("family", ...)` at the end.
