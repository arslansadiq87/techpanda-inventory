import json
from datetime import datetime, timezone
from pathlib import Path
import shutil
import tempfile
import zipfile

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.auth.dependencies import require_roles
from app.core.config import get_settings
from app.database.session import engine
from app.models import User

router = APIRouter(prefix="/backups", tags=["backups"])


def _sqlite_database_path() -> Path:
    settings = get_settings()
    if not settings.database_url.startswith("sqlite:///"):
        raise HTTPException(status_code=400, detail="Only local SQLite backups are supported")
    return Path(settings.database_url.removeprefix("sqlite:///")).resolve()


def _safe_extract(zip_file: zipfile.ZipFile, destination: Path) -> None:
    destination = destination.resolve()
    for member in zip_file.infolist():
        target = (destination / member.filename).resolve()
        if destination != target and destination not in target.parents:
            raise HTTPException(status_code=400, detail="Backup archive contains an unsafe path")
    zip_file.extractall(destination)


@router.post("/manual")
def manual_backup(_user: User = Depends(require_roles("owner"))) -> FileResponse:
    settings = get_settings()
    backup_root = Path(settings.backup_root)
    backup_root.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    backup_path = backup_root / f"tech_panda_inventory_backup_{timestamp}.zip"
    database_path = _sqlite_database_path()
    if not database_path.exists():
        raise HTTPException(status_code=404, detail="Local database file was not found")
    metadata = {
        "created_at": timestamp,
        "type": "manual",
        "status": "success",
        "database": "inventory.sqlite3",
        "media_root": "media",
        "app": settings.app_name,
    }
    with zipfile.ZipFile(backup_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("metadata.json", json.dumps(metadata, indent=2))
        archive.write(database_path, "inventory.sqlite3")
        media_root = Path(settings.media_root)
        if media_root.exists():
            for media_file in media_root.rglob("*"):
                if media_file.is_file():
                    archive.write(media_file, Path("media") / media_file.relative_to(media_root))
    return FileResponse(
        backup_path,
        media_type="application/zip",
        filename=backup_path.name,
    )


@router.post("/restore")
async def restore_backup(
    upload: UploadFile = File(...),
    _user: User = Depends(require_roles("owner")),
) -> dict:
    settings = get_settings()
    database_path = _sqlite_database_path()
    media_root = Path(settings.media_root).resolve()
    backup_root = Path(settings.backup_root).resolve()
    backup_root.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

    suffix = Path(upload.filename or "").suffix.lower()
    if suffix != ".zip":
        raise HTTPException(status_code=400, detail="Please upload a Tech Panda .zip backup")

    with tempfile.TemporaryDirectory() as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        uploaded_path = temp_dir / "backup.zip"
        with uploaded_path.open("wb") as file:
            shutil.copyfileobj(upload.file, file)

        try:
            with zipfile.ZipFile(uploaded_path) as archive:
                names = set(archive.namelist())
                if "metadata.json" not in names or "inventory.sqlite3" not in names:
                    raise HTTPException(status_code=400, detail="Backup is missing required files")
                _safe_extract(archive, temp_dir / "extracted")
        except zipfile.BadZipFile as error:
            raise HTTPException(status_code=400, detail="Invalid backup archive") from error

        extracted = temp_dir / "extracted"
        restored_db = extracted / "inventory.sqlite3"
        restored_media = extracted / "media"
        safety_db = backup_root / f"pre_restore_inventory_{timestamp}.sqlite3"
        safety_media = backup_root / f"pre_restore_media_{timestamp}"

        engine.dispose()
        if database_path.exists():
            shutil.copy2(database_path, safety_db)
        if media_root.exists():
            shutil.copytree(media_root, safety_media)

        database_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(restored_db, database_path)
        if media_root.exists():
            shutil.rmtree(media_root)
        if restored_media.exists():
            shutil.copytree(restored_media, media_root)
        else:
            media_root.mkdir(parents=True, exist_ok=True)

    return {
        "status": "restored",
        "safety_database": safety_db.name if safety_db.exists() else None,
        "safety_media": safety_media.name if safety_media.exists() else None,
    }
