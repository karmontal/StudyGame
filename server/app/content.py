"""Read-only view of the game's curriculum (the repo's data/ folder)."""
import json
import logging
import os

log = logging.getLogger("studygame")

# Copied from scripts/game/rewards.gd (BADGES / LEVEL_TITLES); unknown ids are shown as-is.
BADGES = {
    "first_round": "أول خطوة", "perfect": "علامة كاملة", "combo5": "سلسلة نار", "streak3": "مثابر",
    "streak7": "أسبوع كامل", "correct50": "50 إجابة", "correct200": "200 إجابة", "correct500": "500 إجابة",
    "daily1": "تحدي اليوم", "daily7": "بطل التحديات", "speed10": "سريع البرق", "speed20": "الصاروخ",
    "review10": "تعلّم من أخطائه", "unit_master": "نجم الوحدة", "level5": "متفوق", "stickers5": "صاحب الألبوم",
}
LEVEL_TITLES = ["مبتدئ", "مستكشف", "شاطر", "نبيه", "متفوق", "عبقري", "بطل", "أسطورة"]


def level_title(level: int) -> str:
    return LEVEL_TITLES[max(0, min(int(level) - 1, len(LEVEL_TITLES) - 1))]


def _load(path: str, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as err:
        log.warning("could not read %s: %s", path, err)
        return default


class Content:
    def __init__(self, folder: str):
        self.folder = folder
        self.subjects = _load(os.path.join(folder, "subjects.json"), {})
        self.profiles = _load(os.path.join(folder, "profiles_default.json"), {}).get("profiles", [])
        stickers = _load(os.path.join(folder, "stickers.json"), {}).get("stickers", [])
        self.stickers = {s["id"]: s.get("name", s["id"]) for s in stickers}
        self.books = {}  # id -> {"id","grade","subject","title","units"}
        for entry in _load(os.path.join(folder, "books", "index.json"), {}).get("books", []):
            fname = os.path.basename(entry.get("file", entry["id"] + ".json"))
            book = _load(os.path.join(folder, "books", fname), None)
            if book is None:
                continue
            self.books[entry["id"]] = {
                "id": entry["id"], "grade": int(entry["grade"]), "subject": entry["subject"],
                "title": book.get("title", entry["id"]), "units": book.get("units", []),
            }

    def subject_name(self, subject: str) -> str:
        return self.subjects.get(subject, {}).get("name", subject)

    def subject_color(self, subject: str) -> str:
        return self.subjects.get(subject, {}).get("color", "#888888")

    def books_for_grade(self, grade: int) -> list:
        return [b for b in self.books.values() if b["grade"] == grade]

    def find_lesson(self, key: str):
        """`book/unit/lesson` -> (book, unit, lesson) or None."""
        parts = key.split("/")
        if len(parts) < 3 or parts[0] not in self.books:
            return None
        book = self.books[parts[0]]
        for unit in book["units"]:
            if unit.get("id") == parts[1]:
                for lesson in unit.get("lessons", []):
                    if lesson.get("id") == parts[2]:
                        return book, unit, lesson
        return None

    def lesson_title(self, key: str, fallback: str = "") -> str:
        found = self.find_lesson(key)
        return found[2].get("title", key) if found else (fallback or key)

    def question(self, key: str):
        """`book/unit/lesson/index` -> {"text", "answer", "lesson"} or None."""
        parts = key.split("/")
        if len(parts) != 4 or not parts[3].isdigit():
            return None
        found = self.find_lesson("/".join(parts[:3]))
        if not found:
            return None
        questions = found[2].get("questions", [])
        i = int(parts[3])
        if i >= len(questions):
            return None
        q = questions[i]
        return {"text": q.get("q", ""), "answer": answer_text(q), "lesson": found[2].get("title", "")}


def answer_text(q: dict) -> str:
    kind = q.get("type")
    if kind == "mcq":
        choices = q.get("choices", [])
        a = q.get("answer", 0)
        return choices[a] if isinstance(a, int) and 0 <= a < len(choices) else ""
    if kind == "tf":
        return "صح" if q.get("answer") else "خطأ"
    if kind == "match":
        return "، ".join(f"{a} = {b}" for a, b in q.get("pairs", []))
    if kind == "order":
        return "، ".join(f"{i + 1}) {x}" for i, x in enumerate(q.get("items", [])))
    return ""
