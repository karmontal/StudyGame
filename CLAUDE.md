# StudyGame — notes for Claude

- Kids' quiz game from school-book PDFs (`Books/`, Palestinian 2024 "رزمة تعليمية" packets for Gaza).
  Players: Lamees grade 10, Mufeed grade 8, Lujain grade 5, Nada grade 3 (`data/profiles_default.json`).
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
