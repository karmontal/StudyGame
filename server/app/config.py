"""Settings from environment variables. Refuses to start without a strong key and password."""
import os
from dataclasses import dataclass

MIN_SECRET = 8
DEFAULT_APP_FEED = "https://github.com/karmontal/studygame/releases/download/latest/version.json"


class ConfigError(RuntimeError):
    pass


@dataclass(frozen=True)
class Settings:
    device_key: str
    admin_password: str
    db_path: str = "./data/studygame.db"
    content_dir: str = "../data"
    secure_cookie: bool = False
    # Where the newest game version is announced (version.json of the "latest" release), and an optional
    # download address of your own that replaces the one in it. See docs/sync_api.md, GET /api/app.
    app_feed: str = DEFAULT_APP_FEED
    apk_url: str = ""


def load_settings(env=None) -> Settings:
    env = os.environ if env is None else env
    key = env.get("STUDYGAME_DEVICE_KEY", "")
    password = env.get("STUDYGAME_ADMIN_PASSWORD", "")
    if len(key) < MIN_SECRET:
        raise ConfigError(f"STUDYGAME_DEVICE_KEY must be set (at least {MIN_SECRET} characters)")
    if len(password) < MIN_SECRET:
        raise ConfigError(f"STUDYGAME_ADMIN_PASSWORD must be set (at least {MIN_SECRET} characters)")
    return Settings(
        device_key=key,
        admin_password=password,
        db_path=env.get("STUDYGAME_DB") or "./data/studygame.db",
        content_dir=env.get("STUDYGAME_CONTENT") or "../data",
        secure_cookie=env.get("STUDYGAME_SECURE_COOKIE", "0").lower() in ("1", "true", "yes"),
        app_feed=env.get("STUDYGAME_APP_FEED", DEFAULT_APP_FEED),
        apk_url=env.get("STUDYGAME_APK_URL", ""),
    )
