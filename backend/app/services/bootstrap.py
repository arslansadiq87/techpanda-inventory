from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.security import hash_password, normalize_email
from app.core.config import get_settings
from app.models import Category, ComponentType, User, Workspace


DEFAULT_CATEGORIES = [
    ("Resistors", "RES"),
    ("Capacitors", "CAP"),
    ("Development Boards", "DEV"),
    ("Sensors", "SNS"),
    ("DC Buck Converters", "BUC"),
    ("Tools", "TLS"),
    ("Consumables", "CON"),
]

DEFAULT_COMPONENT_TYPES = [
    "Resistor",
    "Capacitor",
    "Transistor",
    "Diode",
    "LED",
    "Inductor",
    "Integrated Circuit",
    "Microcontroller",
    "Sensor",
    "Module",
    "Connector",
    "Switch",
    "Relay",
    "Voltage Regulator",
    "Crystal/Oscillator",
    "Fuse",
    "Potentiometer",
    "Transformer",
    "Battery",
    "Motor",
    "Display",
    "Cable/Wire",
    "Mechanical",
    "Other",
]


def normalize_name(value: str) -> str:
    return value.strip().lower()


def ensure_component_types(db: Session, workspace: Workspace) -> None:
    existing = set(db.scalars(select(ComponentType.normalized_name).where(ComponentType.workspace_id == workspace.id)))
    for index, name in enumerate(DEFAULT_COMPONENT_TYPES):
        normalized = normalize_name(name)
        if normalized not in existing:
            db.add(ComponentType(workspace_id=workspace.id, name=name, normalized_name=normalized, display_order=index))
    db.commit()


def ensure_workspace(db: Session) -> Workspace:
    workspace = db.scalars(select(Workspace).limit(1)).first()
    if workspace:
        ensure_component_types(db, workspace)
        return workspace
    settings = get_settings()
    workspace = Workspace(
        name="Tech Panda",
        default_currency=settings.default_currency,
        default_unit=settings.default_unit,
        timezone=settings.timezone,
    )
    db.add(workspace)
    db.flush()
    for name, prefix in DEFAULT_CATEGORIES:
        db.add(Category(workspace_id=workspace.id, name=name, normalized_name=name.lower(), code_prefix=prefix))
    db.commit()
    db.refresh(workspace)
    ensure_component_types(db, workspace)
    return workspace


def ensure_admin(db: Session) -> None:
    settings = get_settings()
    username = (settings.admin_name or "admin").strip().lower()
    admin_email = f"{username}@tech-panda.local"
    existing_admin = db.scalars(select(User).where(User.name == username)).first()
    if existing_admin:
        return
    if db.scalars(select(User).limit(1)).first():
        return
    if not settings.admin_password:
        return
    user = User(
        name=username,
        email=admin_email,
        normalized_email=normalize_email(admin_email),
        password_hash=hash_password(settings.admin_password),
        role="owner",
    )
    db.add(user)
    db.commit()
