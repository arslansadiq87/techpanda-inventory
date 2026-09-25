from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.auth.security import create_access_token, create_refresh_token, hash_password, hash_token, verify_password
from app.core.config import get_settings
from app.database.session import get_db
from app.models import RefreshToken, User
from app.schemas.auth import ChangePasswordRequest, LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


def normalize_login(value: str) -> str:
    return value.strip().lower()


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)) -> TokenResponse:
    settings = get_settings()
    user = db.scalars(select(User).where(User.name == normalize_login(payload.username))).first()
    if not user or not verify_password(payload.password, user.password_hash):
        if user:
            user.failed_login_count += 1
            db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is inactive")

    access_token = create_access_token(user.id, user.role)
    refresh_token = create_refresh_token()
    user.last_login_at = datetime.now(timezone.utc)
    user.failed_login_count = 0
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh_token),
            device_name=payload.device_name,
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_days),
        )
    )
    db.commit()
    cookie_max_age = settings.access_token_minutes * 60 if settings.access_token_minutes > 0 else 10 * 365 * 24 * 60 * 60
    response.set_cookie("access_token", access_token, httponly=True, secure=True, samesite="strict", max_age=cookie_max_age)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_minutes * 60 if settings.access_token_minutes > 0 else cookie_max_age,
        user={"id": user.id, "username": user.name, "role": user.role},
    )


@router.get("/me")
def me(user: User = Depends(get_current_user)) -> dict:
    return {"id": user.id, "username": user.name, "role": user.role}


@router.post("/change-password")
def change_password(payload: ChangePasswordRequest, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"status": "changed"}


@router.post("/logout")
def logout(response: Response) -> dict:
    response.delete_cookie("access_token")
    return {"status": "logged_out"}
