import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy.orm import Session

from app.auth.dependencies import require_roles
from app.core.config import get_settings
from app.database.session import get_db
from app.models import Project, User
from app.schemas.common import ProjectRead
from app.services.inventory_service import get_workspace

router = APIRouter(
    prefix="/projects/{project_id}/image",
    tags=["project images"],
)

ALLOWED_IMAGE_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


@router.post("", response_model=ProjectRead)
def upload_project_image(
    project_id: str,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Project:
    workspace = get_workspace(db)
    project = db.get(Project, project_id)
    if (
        not project
        or project.workspace_id != workspace.id
        or project.is_archived
    ):
        raise HTTPException(status_code=404, detail="Project not found")

    suffix = Path(upload.filename or "image.jpg").suffix.lower() or ".jpg"
    inferred_type = ALLOWED_IMAGE_TYPES.get(suffix)
    content_type = (
        upload.content_type
        if upload.content_type in set(ALLOWED_IMAGE_TYPES.values())
        else inferred_type
    )
    if content_type not in set(ALLOWED_IMAGE_TYPES.values()):
        raise HTTPException(
            status_code=400,
            detail="Only JPEG, PNG, and WebP images are allowed",
        )

    destination = Path(get_settings().media_root) / "projects"
    destination.mkdir(parents=True, exist_ok=True)
    image_path = destination / f"{uuid.uuid4()}.jpg"
    try:
        upload.file.seek(0)
        with Image.open(upload.file) as source:
            normalized = ImageOps.exif_transpose(source)
            if normalized.mode in {"RGBA", "LA"}:
                background = Image.new("RGB", normalized.size, "white")
                alpha = normalized.getchannel("A")
                background.paste(normalized.convert("RGB"), mask=alpha)
                normalized = background
            else:
                normalized = normalized.convert("RGB")
            normalized.thumbnail((1600, 1600))
            normalized.save(image_path, "JPEG", quality=84, optimize=True)
    except (UnidentifiedImageError, OSError, ValueError) as error:
        image_path.unlink(missing_ok=True)
        raise HTTPException(status_code=400, detail="Invalid image file") from error

    previous_path = Path(project.image_path) if project.image_path else None
    project.image_path = str(image_path)
    db.commit()
    db.refresh(project)
    if previous_path and previous_path != image_path:
        try:
            previous_path.unlink(missing_ok=True)
        except OSError:
            pass
    return project
