from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Tech Panda Components Inventory"
    app_version: str = "0.1.0"
    environment: str = "local"
    database_url: str = Field(default="sqlite:///../local_data/inventory.sqlite3")
    # Must be supplied through JWT_SECRET in every deployed environment.
    jwt_secret: str = Field(default="")
    jwt_issuer: str = "tech-panda-inventory"
    access_token_minutes: int = 0
    refresh_token_days: int = 30
    media_root: Path = Path("../local_data/media")
    backup_root: Path = Path("../local_data/backups")
    exports_root: Path = Path("../local_data/exports")
    timezone: str = "Asia/Karachi"
    default_currency: str = "CNY"
    default_unit: str = "Pieces"
    admin_name: str = "admin"
    admin_email: str = ""
    # Bootstrap is intentionally disabled until ADMIN_PASSWORD is configured.
    admin_password: str = ""
    cors_origins: str = "*"
    voice_assistant_api_key: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def normalized_cors_origins(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
