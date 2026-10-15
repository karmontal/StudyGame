"""Game <-> server API, exactly as docs/sync_api.md."""
import hmac
import json
from datetime import datetime
from typing import Annotated, Any, Literal

from fastapi import APIRouter, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, ValidationError, field_validator

from . import db, updates

MAX_BODY = 1024 * 1024
MAX_EVENTS = 500

Id = Annotated[str, StringConstraints(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9_.:-]+$")]
Short = Annotated[str, StringConstraints(max_length=200)]
Key = Annotated[str, StringConstraints(max_length=200)]
Count = Annotated[int, Field(ge=0, le=1_000_000)]


class Profile(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: Id
    name: Annotated[str, StringConstraints(min_length=1, max_length=60)]
    grade: Annotated[int, Field(ge=0, le=12)]  # 0 = toddler (no school books)


class Event(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: Annotated[str, StringConstraints(min_length=1, max_length=100)]
    profile: Id
    kind: Literal["lesson", "unit", "review", "daily", "speed", "assignment", "family"]
    lesson_key: Key = ""
    book: Short = ""
    unit: Short = ""
    title: Short = ""
    stars: Annotated[int, Field(ge=0, le=3)] = 0
    correct: Count = 0
    total: Count = 0
    coins: Count = 0
    assignment: Short = ""
    wrong: Annotated[list[Key], Field(max_length=200)] = []
    at: str

    @field_validator("at")
    @classmethod
    def _at_format(cls, v: str) -> str:
        datetime.strptime(v, "%Y-%m-%dT%H:%M:%S")
        return v


class SyncRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")
    device: Short = ""
    profiles: Annotated[list[Profile], Field(max_length=20)] = []
    events: Annotated[list[Event], Field(max_length=MAX_EVENTS)] = []
    summary: Annotated[dict[Id, dict[str, Any]], Field(max_length=20)] = {}


def make_router(settings, latest=None) -> APIRouter:
    router = APIRouter(prefix="/api")
    latest = latest or updates.Latest(settings)

    def check_key(request: Request) -> None:
        given = request.headers.get("x-device-key", "")
        if not hmac.compare_digest(given.encode(), settings.device_key.encode()):
            raise HTTPException(status_code=401, detail="bad device key")

    @router.get("/ping")
    def ping(request: Request):
        check_key(request)
        return {"ok": True}

    @router.get("/app")
    async def app_version(request: Request):
        """The newest game version and where to download it; code 0 when unknown."""
        check_key(request)
        return await run_in_threadpool(latest.get)

    @router.post("/sync")
    async def sync(request: Request):
        check_key(request)
        length = request.headers.get("content-length", "")
        if length.isdigit() and int(length) > MAX_BODY:
            raise HTTPException(status_code=413, detail="body too large")
        body = bytearray()
        async for chunk in request.stream():
            body += chunk
            if len(body) > MAX_BODY:
                raise HTTPException(status_code=413, detail="body too large")
        try:
            req = SyncRequest.model_validate(json.loads(body))
        except (ValueError, ValidationError) as err:
            detail = err.errors(include_url=False, include_input=False, include_context=False) if isinstance(err, ValidationError) else "invalid JSON"
            raise HTTPException(status_code=422, detail=detail) from None

        def work():
            with db.connect(settings.db_path) as conn:
                db.apply_sync(conn, req)
                sent = {pid: str(s.get("changed_at", "")) for pid, s in req.summary.items()}
                sent.update({p.id: sent.get(p.id, "") for p in req.profiles})
                return db.pending_assignments(conn), db.newer_kid_states(conn, sent)

        assignments, kids = await run_in_threadpool(work)
        return {"ok": True, "assignments": assignments, "kids": kids}

    return router
