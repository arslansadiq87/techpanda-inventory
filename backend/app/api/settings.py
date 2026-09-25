import json
from pathlib import Path

from fastapi import APIRouter, Depends

from app.auth.dependencies import require_roles
from app.core.config import get_settings
from app.models import User

router = APIRouter(prefix="/settings", tags=["settings"])


def _settings_path() -> Path:
    return Path(get_settings().backup_root).resolve().parent / "settings.json"


def _read_settings() -> dict:
    path = _settings_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _write_settings(settings: dict) -> None:
    path = _settings_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(settings, indent=2), encoding="utf-8")


@router.get("/ui")
def ui_settings() -> dict:
    settings = _read_settings()
    return {"dark_mode": bool(settings.get("dark_mode", False))}


@router.put("/ui")
def update_ui_settings(
    payload: dict,
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> dict:
    settings = _read_settings()
    settings["dark_mode"] = bool(payload.get("dark_mode", False))
    _write_settings(settings)
    return {"dark_mode": settings["dark_mode"]}
