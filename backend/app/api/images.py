import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from PIL import Image
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.core.config import get_settings
from app.database.session import get_db
from app.models import Component, ComponentImage, User

router = APIRouter(prefix="/components/{component_id}/images", tags=["images"])

ALLOWED_IMAGE_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


def image_url(kind: str, stored_filename: str) -> str:
    return f"/api/v1/media/{kind}/{stored_filename}"


def image_payload(record: ComponentImage) -> dict:
    return {
        "id": record.id,
        "filename": record.original_filename,
        "mime_type": record.mime_type,
        "thumbnail": image_url("thumbnails", record.stored_filename),
        "preview": image_url("previews", record.stored_filename),
        "is_primary": record.is_primary,
    }


def remove_image_files(record: ComponentImage) -> None:
    for image_path in (
        record.original_path,
        record.preview_path,
        record.thumbnail_path,
    ):
        try:
            Path(image_path).unlink(missing_ok=True)
        except OSError:
            # A missing or locked derivative must not prevent the database
            # record from being replaced.
            continue


@router.get("")
def list_images(
    component_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[dict]:
    component = db.get(Component, component_id)
    if not component:
        raise HTTPException(status_code=404, detail="Component not found")
    records = db.scalars(select(ComponentImage).where(ComponentImage.component_id == component.id).order_by(ComponentImage.is_primary.desc(), ComponentImage.created_at.desc()))
    return [image_payload(record) for record in records]


@router.post("")
def upload_image(
    component_id: str,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> dict:
    component = db.get(Component, component_id)
    if not component:
        raise HTTPException(status_code=404, detail="Component not found")
    suffix = Path(upload.filename or "image.jpg").suffix.lower() or ".jpg"
    inferred_content_type = ALLOWED_IMAGE_TYPES.get(suffix)
    content_type = upload.content_type if upload.content_type in set(ALLOWED_IMAGE_TYPES.values()) else inferred_content_type
    if content_type not in set(ALLOWED_IMAGE_TYPES.values()):
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, and WebP images are allowed")
    settings = get_settings()
    originals = Path(settings.media_root) / "originals"
    previews = Path(settings.media_root) / "previews"
    thumbnails = Path(settings.media_root) / "thumbnails"
    for directory in (originals, previews, thumbnails):
        directory.mkdir(parents=True, exist_ok=True)
    stored = f"{uuid.uuid4()}{suffix}"
    original_path = originals / stored
    with original_path.open("wb") as fh:
        shutil.copyfileobj(upload.file, fh)
    with Image.open(original_path) as img:
        width, height = img.size
        preview = img.copy()
        preview.thumbnail((1200, 1200))
        preview.save(previews / stored)
        thumb = img.copy()
        thumb.thumbnail((320, 320))
        thumb.save(thumbnails / stored)

    existing_records = list(
        db.scalars(
            select(ComponentImage).where(
                ComponentImage.component_id == component.id,
            )
        ).all()
    )
    record = ComponentImage(
        component_id=component.id,
        original_filename=upload.filename or stored,
        stored_filename=stored,
        mime_type=content_type or "application/octet-stream",
        file_size=original_path.stat().st_size,
        width=width,
        height=height,
        original_path=str(original_path),
        preview_path=str(previews / stored),
        thumbnail_path=str(thumbnails / stored),
        is_primary=True,
        created_by=user.id,
    )
    for existing in existing_records:
        db.delete(existing)
    db.add(record)
    db.commit()
    for existing in existing_records:
        remove_image_files(existing)
    db.refresh(record)
    return image_payload(record)
