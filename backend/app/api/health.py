from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import __version__
from app.core.config import get_settings
from app.database.session import get_db

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/live")
def live() -> dict:
    return {"status": "ok", "version": __version__}


@router.get("/ready")
def ready(db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    try:
        db.execute(text("select 1"))
        for path in (settings.media_root, settings.backup_root, settings.exports_root):
            Path(path).mkdir(parents=True, exist_ok=True)
            if not Path(path).exists():
                raise RuntimeError(f"{path} missing")
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Not ready") from exc
    return {"status": "ready", "version": __version__}


@router.get("/version")
def version() -> dict:
    settings = get_settings()
    return {"name": settings.app_name, "version": settings.app_version, "environment": settings.environment}
