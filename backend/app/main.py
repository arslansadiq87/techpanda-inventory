from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import auth, backups, health, images, inventory, project_images, settings as app_settings, voice
from app.core.config import get_settings
from app.database.session import SessionLocal, engine
from app.models import Base
from app.services.bootstrap import ensure_admin, ensure_workspace


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if settings.environment == "test" or settings.database_url.startswith("sqlite"):
        Base.metadata.create_all(bind=engine)
        with engine.connect() as conn:
            columns = [col[1] for col in conn.exec_driver_sql("PRAGMA table_info(components)").fetchall()]
            if columns and "price" not in columns:
                conn.exec_driver_sql("ALTER TABLE components ADD COLUMN price NUMERIC")
            if columns:
                if "price" not in columns:
                    conn.exec_driver_sql("ALTER TABLE components ADD COLUMN price NUMERIC")
                if "datasheet_text" not in columns:
                    conn.exec_driver_sql("ALTER TABLE components ADD COLUMN datasheet_text TEXT")
                if "expiry_date" not in columns:
                    conn.exec_driver_sql("ALTER TABLE components ADD COLUMN expiry_date VARCHAR(20)")
                conn.commit()
            type_cols = [col[1] for col in conn.exec_driver_sql("PRAGMA table_info(component_types)").fetchall()]
            if type_cols and "parent_type_id" not in type_cols:
                conn.exec_driver_sql("ALTER TABLE component_types ADD COLUMN parent_type_id VARCHAR(36)")
            conn.commit()
    db = SessionLocal()
    try:
        ensure_workspace(db)
        ensure_admin(db)
    finally:
        db.close()
    yield


settings = get_settings()
Path(settings.media_root).mkdir(parents=True, exist_ok=True)
app = FastAPI(title=settings.app_name, version=settings.app_version, docs_url="/docs" if settings.environment != "production" else None, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.normalized_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api/v1")
app.include_router(auth.router, prefix="/api/v1")
app.include_router(inventory.router, prefix="/api/v1")
app.include_router(images.router, prefix="/api/v1")
app.include_router(project_images.router, prefix="/api/v1")
app.include_router(backups.router, prefix="/api/v1")
app.include_router(app_settings.router, prefix="/api/v1")
app.include_router(voice.router, prefix="/api/v1")
app.include_router(voice.router, prefix="/api")

app.mount("/api/v1/media", StaticFiles(directory=str(settings.media_root)), name="media")


@app.middleware("http")
async def no_cache_static(request: Request, call_next):
    response = await call_next(request)
    path = request.url.path
    if path == "/" or path.endswith((".html", ".js", ".json")):
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


static_web_dir = Path("/app/static_web")
if not static_web_dir.is_dir():
    static_web_dir = Path(__file__).resolve().parent.parent / "static_web"

if static_web_dir.is_dir() and (static_web_dir / "index.html").exists():
    app.mount("/", StaticFiles(directory=str(static_web_dir), html=True), name="static_web")
else:
    @app.get("/")
    def root():
        return {
            "app": settings.app_name,
            "status": "online",
            "version": settings.app_version,
            "api_base": "/api/v1",
            "health": "/api/v1/health/live",
        }


