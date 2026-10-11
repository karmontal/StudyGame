"""App factory. Run: uvicorn app.main:create_app --factory"""
import hashlib
import logging
import os

from fastapi import FastAPI, Request
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware

from . import api, db, web
from .config import Settings, load_settings
from .content import Content


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or load_settings()
    content = Content(settings.content_dir)
    if not content.books:
        logging.getLogger("studygame").warning("no books found in %s (STUDYGAME_CONTENT)", settings.content_dir)
    db.init(settings.db_path, content.profiles)

    app = FastAPI(title="StudyGame parent dashboard", docs_url=None, redoc_url=None, openapi_url=None)
    # Session cookie signed with a key derived from the admin password: changing the password logs everyone out.
    secret = hashlib.sha256(("studygame-session:" + settings.admin_password).encode()).hexdigest()
    app.add_middleware(SessionMiddleware, secret_key=secret, session_cookie="studygame_session",
                       max_age=30 * 24 * 3600, same_site="lax", https_only=settings.secure_cookie)
    app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")
    app.include_router(api.make_router(settings))
    app.include_router(web.make_router(settings, content))

    @app.exception_handler(web.NeedLogin)
    async def _need_login(request: Request, exc: web.NeedLogin):
        return RedirectResponse("/login", status_code=303)

    @app.get("/healthz")
    def healthz():
        return {"ok": True}

    app.state.settings = settings
    app.state.content = content
    return app
