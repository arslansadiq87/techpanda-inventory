from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=3)
    password: str = Field(min_length=1)
    device_name: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: dict


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=1)
