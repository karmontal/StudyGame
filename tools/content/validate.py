"""Check data/books/<id>.json files with the same rules as Content.validate_book() in content.gd.
Run: python3 tools/content/validate.py [book_id ...]   (no args = every book with a JSON file)
"""
import json, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
TYPES = ("mcq", "tf", "match", "order")


def check_question(q, where):
    errs = []
    t = q.get("type")
    if t not in TYPES:
        return [f"{where}: unknown type {t!r}"]
    if not str(q.get("q", "")).strip():
        errs.append(f"{where}: empty question text")
    if t == "mcq":
        ch = q.get("choices", [])
        if not 2 <= len(ch) <= 4:
            errs.append(f"{where}: mcq needs 2-4 choices")
        a = q.get("answer")
        if not isinstance(a, int) or isinstance(a, bool) or not 0 <= a < len(ch):
            errs.append(f"{where}: mcq answer index out of range")
        if len(set(map(str, ch))) != len(ch):
            errs.append(f"{where}: duplicate choice")
    elif t == "tf":
        if not isinstance(q.get("answer"), bool):
            errs.append(f"{where}: tf answer must be true/false")
    elif t == "match":
        pairs = q.get("pairs", [])
        if not 2 <= len(pairs) <= 5:
            errs.append(f"{where}: match needs 2-5 pairs")
        for p in pairs:
            if not isinstance(p, list) or len(p) != 2:
                errs.append(f"{where}: each pair needs two items")
        if len({str(p[0]) for p in pairs}) != len(pairs) or len({str(p[1]) for p in pairs}) != len(pairs):
            errs.append(f"{where}: match sides must be unique")
    elif t == "order":
        items = q.get("items", [])
        if not 3 <= len(items) <= 6:
            errs.append(f"{where}: order needs 3-6 items")
        if len(set(map(str, items))) != len(items):
            errs.append(f"{where}: duplicate order item")
    return errs


def check_book(book_id):
    path = os.path.join(ROOT, "data", "books", book_id + ".json")
    with open(path, encoding="utf-8") as f:
        book = json.load(f)
    errs = []
    if book.get("id") != book_id:
        errs.append(f"{book_id}: id mismatch")
    if book.get("lang") not in ("ar", "en"):
        errs.append(f"{book_id}: lang must be ar or en")
    if not book.get("units"):
        errs.append(f"{book_id}: no units")
    seen_q, uids = set(), set()
    count = 0
    for u in book.get("units", []):
        uw = f"{book_id}/{u.get('id')}"
        if u.get("id") in uids:
            errs.append(uw + ": duplicate unit id")
        uids.add(u.get("id"))
        if not u.get("title"):
            errs.append(uw + ": unit needs a title")
        lids = set()
        for l in u.get("lessons", []):
            lw = f"{uw}/{l.get('id')}"
            if l.get("id") in lids:
                errs.append(lw + ": duplicate lesson id")
            lids.add(l.get("id"))
            if not l.get("title"):
                errs.append(lw + ": lesson needs a title")
            for i, q in enumerate(l.get("questions", [])):
                errs += check_question(q, f"{lw}#{i}")
                text = str(q.get("q", "")).strip()
                if q.get("type") in ("mcq", "tf") and text in seen_q:
                    errs.append(f"{lw}#{i}: same question text used twice in this book")
                seen_q.add(text)
                count += 1
    return errs, count


def main(ids):
    if not ids:
        ids = sorted(f[:-5] for f in os.listdir(os.path.join(ROOT, "data", "books")) if f.endswith(".json") and f != "index.json")
    bad = 0
    for b in ids:
        errs, n = check_book(b)
        print(f"{b}: {n} questions, {len(errs)} errors")
        for e in errs:
            print("  " + e)
        bad += len(errs)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
