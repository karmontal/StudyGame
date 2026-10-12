"""Parent dashboard (Arabic, RTL, server-rendered)."""
import asyncio
import hmac
import json
import os
import secrets
from datetime import datetime

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from . import db, stats
from .content import BADGES as BADGE_NAMES

TEMPLATES = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))
TEMPLATES.env.globals["grade_label"] = lambda g: "الصف %d" % g if int(g) > 0 else "ألعاب الصغار"


class NeedLogin(Exception):
    pass


def _parse(at):
    try:
        return datetime.strptime(at, "%Y-%m-%dT%H:%M:%S")
    except (TypeError, ValueError):
        return None


def fmt_time(at) -> str:
    t = _parse(at)
    return t.strftime("%d/%m %H:%M") if t else "—"


def ago(at) -> str:
    t = _parse(at)
    if not t:
        return "لم يلعب بعد"
    days = (datetime.now().date() - t.date()).days
    if days <= 0:
        return "اليوم " + t.strftime("%H:%M")
    if days == 1:
        return "أمس " + t.strftime("%H:%M")
    if days == 2:
        return "قبل يومين"
    if days <= 10:
        return f"قبل {days} أيام"
    return t.strftime("%d/%m/%Y")


TEMPLATES.env.filters["fmt_time"] = fmt_time
TEMPLATES.env.filters["ago"] = ago


def make_router(settings, content) -> APIRouter:
    router = APIRouter()

    def page(request: Request, name: str, **ctx):
        ctx.setdefault("csrf", request.session.get("csrf", ""))
        return TEMPLATES.TemplateResponse(request, name, ctx)

    def require_login(request: Request) -> None:
        if not request.session.get("user"):
            raise NeedLogin()

    def require_post(request: Request, token: str) -> None:
        require_login(request)
        if not hmac.compare_digest(token.encode(), request.session.get("csrf", "").encode()):
            raise NeedLogin()

    def conn():
        return db.connect(settings.db_path)

    # ----- login -----

    @router.get("/login", response_class=HTMLResponse)
    def login_form(request: Request):
        return page(request, "login.html", error=False)

    @router.post("/login")
    async def login(request: Request, password: str = Form("")):
        if hmac.compare_digest(password.encode(), settings.admin_password.encode()):
            request.session.clear()
            request.session["user"] = "parent"
            request.session["csrf"] = secrets.token_urlsafe(24)
            return RedirectResponse("/", status_code=303)
        await asyncio.sleep(1)  # slow down guessing
        return page(request, "login.html", error=True)

    @router.post("/logout")
    def logout(request: Request):
        request.session.clear()
        return RedirectResponse("/login", status_code=303)

    # ----- pages -----

    @router.get("/", response_class=HTMLResponse)
    def overview(request: Request):
        require_login(request)
        with conn() as c:
            cards = [stats.overview_card(c, p) for p in stats.profiles(c)]
        return page(request, "overview.html", cards=cards, nav="home")

    @router.get("/kid/{pid}", response_class=HTMLResponse)
    def kid(request: Request, pid: str):
        require_login(request)
        with conn() as c:
            p = stats.profile(c, pid)
            if not p:
                return RedirectResponse("/", status_code=303)
            s = stats.summary(c, pid)
            ctx = {
                "kid": p, "card": stats.overview_card(c, p), "summary": s,
                "subjects": stats.lesson_tree(c, content, p, s),
                "events": stats.recent_events(c, content, pid),
                "badges": stats.badges(s), "stickers": stats.stickers(content, s),
                "wrong": stats.most_wrong(c, content, pid),
                "assignments": stats.assignments(c, content, pid),
                "adjustments": stats.adjustments(c, pid), "lessons": stats.lesson_choices(content, s),
                "badge_choices": stats.badge_choices(s), "sticker_choices": stats.sticker_choices(content, s),
            }
        return page(request, "kid.html", nav="home", **ctx)

    @router.get("/kid/{pid}/week", response_class=HTMLResponse)
    def week(request: Request, pid: str):
        require_login(request)
        with conn() as c:
            p = stats.profile(c, pid)
            if not p:
                return RedirectResponse("/", status_code=303)
            report = stats.weekly(c, content, pid)
            done = [a for a in stats.assignments(c, content, pid) if a["status"] != "open"
                    and (a["done_at"] or "") >= stats.since(7)]
        return page(request, "week.html", nav="home", kid=p, r=report, done=done)

    # ----- assignments -----

    @router.get("/assignments", response_class=HTMLResponse)
    def assignment_list(request: Request):
        require_login(request)
        with conn() as c:
            items = stats.assignments(c, content)
        return page(request, "assignments.html", nav="assign", items=items)

    @router.get("/assignments/new", response_class=HTMLResponse)
    def assignment_new(request: Request, kid: str = "", book: str = "", error: str = ""):
        require_login(request)
        with conn() as c:
            kids = stats.profiles(c)
        chosen = next((k for k in kids if k["id"] == kid), None)
        books = []
        if chosen:
            books = [{"id": b["id"], "title": b["title"], "name": content.subject_name(b["subject"])}
                     for b in content.books_for_grade(chosen["grade"])]
        chosen_book = content.books.get(book) if chosen and book in {b["id"] for b in books} else None
        return page(request, "assignment_new.html", nav="assign", kids=kids, kid=chosen, books=books,
                    book=chosen_book, error=error)

    @router.post("/assignments")
    async def assignment_create(request: Request):
        form = await request.form()
        require_post(request, str(form.get("csrf", "")))
        kid = str(form.get("kid", ""))
        book_id = str(form.get("book", ""))
        keys = [str(k) for k in form.getlist("lessons")]
        back = f"/assignments/new?kid={kid}&book={book_id}&error="
        with conn() as c:
            p = stats.profile(c, kid)
            book = content.books.get(book_id)
            if not p or not book or book["grade"] != p["grade"]:
                return RedirectResponse(back + "kid", status_code=303)
            valid = [k for k in dict.fromkeys(keys) if k.startswith(book_id + "/") and content.find_lesson(k)]
            if not valid or len(valid) != len(set(keys)):
                return RedirectResponse(back + "lessons", status_code=303)
            try:
                count = int(form.get("count", 10))
                min_stars = int(form.get("min_stars", 2))
            except ValueError:
                return RedirectResponse(back + "numbers", status_code=303)
            if not (5 <= count <= 20 and 1 <= min_stars <= 3):
                return RedirectResponse(back + "numbers", status_code=303)
            title = str(form.get("title", "")).strip()[:80] or ("اختبار " + content.subject_name(book["subject"]))
            c.execute(
                "INSERT INTO assignments (profile, title, note, reward, lesson_keys, count, min_stars, created_at)"
                " VALUES (?,?,?,?,?,?,?,?)",
                (kid, title, str(form.get("note", "")).strip()[:300], str(form.get("reward", "")).strip()[:120],
                 json.dumps(valid), count, min_stars, db.now_str()),
            )
        return RedirectResponse("/assignments", status_code=303)

    @router.post("/assignments/{aid}/reward")
    def assignment_reward(request: Request, aid: int, csrf: str = Form("")):
        require_post(request, csrf)
        with conn() as c:
            c.execute("UPDATE assignments SET reward_given_at=? WHERE id=? AND reward_given_at IS NULL",
                      (db.now_str(), aid))
        return RedirectResponse("/assignments", status_code=303)

    @router.post("/assignments/{aid}/delete")
    def assignment_delete(request: Request, aid: int, csrf: str = Form("")):
        require_post(request, csrf)
        with conn() as c:
            c.execute("DELETE FROM assignments WHERE id=?", (aid,))
        return RedirectResponse("/assignments", status_code=303)

    # ----- parent adjustments: the phone applies them on its next sync -----

    @router.post("/kid/{pid}/adjust")
    async def adjust(request: Request, pid: str):
        form = await request.form()
        require_post(request, str(form.get("csrf", "")))
        kind = str(form.get("kind", ""))
        target = str(form.get("target", "")).strip()[:200]
        reason = str(form.get("reason", "")).strip()[:200]
        amount = 0
        with conn() as c:
            if not stats.profile(c, pid):
                return RedirectResponse("/", status_code=303)
            if kind == "coins":
                try:
                    amount = int(form.get("amount", 0))
                except ValueError:
                    amount = 0
                if not 1 <= amount <= 500:
                    return RedirectResponse(f"/kid/{pid}?error=amount", status_code=303)
                target = ""
            elif kind == "lesson":
                found = content.find_lesson(target)
                if not found or target.count("/") != 2:
                    return RedirectResponse(f"/kid/{pid}?error=target", status_code=303)
            elif kind == "badge":
                if target not in content_badge_ids():
                    return RedirectResponse(f"/kid/{pid}?error=target", status_code=303)
            elif kind == "sticker":
                if target not in content.stickers:
                    return RedirectResponse(f"/kid/{pid}?error=target", status_code=303)
            else:
                return RedirectResponse(f"/kid/{pid}?error=kind", status_code=303)
            c.execute(
                "INSERT INTO adjustments (profile, kind, target, amount, reason, created_at) VALUES (?,?,?,?,?,?)",
                (pid, kind, target, amount, reason, db.now_str()),
            )
        return RedirectResponse(f"/kid/{pid}", status_code=303)

    def content_badge_ids():
        return set(BADGE_NAMES)

    return router
