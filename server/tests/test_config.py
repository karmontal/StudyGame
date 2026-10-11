import pytest

from app.config import ConfigError, load_settings
from app.main import create_app


def test_missing_password_refuses_start(monkeypatch):
    monkeypatch.setenv("STUDYGAME_DEVICE_KEY", "long-enough-key")
    monkeypatch.delenv("STUDYGAME_ADMIN_PASSWORD", raising=False)
    with pytest.raises(ConfigError):
        create_app()


def test_short_key_refuses_start():
    with pytest.raises(ConfigError):
        load_settings({"STUDYGAME_DEVICE_KEY": "short", "STUDYGAME_ADMIN_PASSWORD": "long-enough-pass"})


def test_short_password_refuses_start():
    with pytest.raises(ConfigError):
        load_settings({"STUDYGAME_DEVICE_KEY": "long-enough-key", "STUDYGAME_ADMIN_PASSWORD": "1234567"})


def test_defaults():
    s = load_settings({"STUDYGAME_DEVICE_KEY": "long-enough-key", "STUDYGAME_ADMIN_PASSWORD": "long-enough-pass"})
    assert s.db_path == "./data/studygame.db" and s.content_dir == "../data"
