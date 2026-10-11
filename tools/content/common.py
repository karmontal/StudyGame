"""Helpers for writing book files. Each tools/content/<book>.py builds a dict and calls write_book().

Question types (see scripts/autoload/content.gd for the validator):
  mcq(q, choices, answer=0)  2-4 choices, answer = index of the right one (the game shuffles them)
  tf(q, True/False)
  match(q, [[left, right], ...])  2-5 pairs
  order(q, [first, second, ...])  3-6 items in the right order
Every helper takes an optional explain= shown after the answer.
"""
import json, os

def _q(d, explain):
    if explain:
        d["explain"] = explain
    return d

def mcq(q, choices, answer=0, explain=""):
    return _q({"type": "mcq", "q": q, "choices": choices, "answer": answer}, explain)

def tf(q, answer, explain=""):
    return _q({"type": "tf", "q": q, "answer": answer}, explain)

def match(q, pairs, explain=""):
    return _q({"type": "match", "q": q, "pairs": pairs}, explain)

def order(q, items, explain=""):
    return _q({"type": "order", "q": q, "items": items}, explain)

def lesson(id, title, pages=None, questions=None):
    d = {"id": id, "title": title}
    if pages:
        d["pages"] = pages
    d["questions"] = questions or []
    return d

def write_book(book):
    out = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "data", "books", book["id"] + ".json"))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(book, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    n = sum(len(l.get("questions", [])) for u in book["units"] for l in u["lessons"])
    print("wrote", out, n, "questions")
