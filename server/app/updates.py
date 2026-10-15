"""The newest game version, for GET /api/app: read from the release's version.json and kept for a while."""
import json
import time
import urllib.request

CACHE_SECONDS = 600
TIMEOUT = 5
NONE = {"code": 0, "name": "", "url": ""}


def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=TIMEOUT) as r:  # noqa: S310 (address from the server's own settings)
        return json.loads(r.read(64 * 1024))


class Latest:
    def __init__(self, settings, fetch=None):
        self.settings = settings
        self.fetch = fetch
        self._value = None
        self._at = 0.0

    def get(self) -> dict:
        if self._value is None or time.monotonic() - self._at > CACHE_SECONDS:
            fresh = self._read()
            # A failed read keeps the last good answer; with none yet the game is told nothing is newer.
            if fresh is not None or self._value is None:
                self._value = fresh or dict(NONE)
            self._at = time.monotonic()
        return dict(self._value)

    def _read(self):
        if not self.settings.app_feed:
            return None
        try:
            data = (self.fetch or fetch_json)(self.settings.app_feed)
            code, name, url = int(data["code"]), str(data.get("name", ""))[:40], str(data.get("url", ""))
        except Exception:  # noqa: BLE001 (network, JSON or shape: all mean "unknown for now")
            return None
        url = self.settings.apk_url or url
        if code <= 0 or not url.startswith("https://"):
            return None
        return {"code": code, "name": name, "url": url}
