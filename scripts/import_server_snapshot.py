from __future__ import annotations

import csv
from datetime import datetime
from decimal import Decimal
import shutil
import sys
from pathlib import Path

from sqlalchemy import create_engine, insert
from sqlalchemy.orm import sessionmaker
from sqlalchemy.sql.sqltypes import Boolean, DateTime, Integer, Numeric

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.models import Base  # noqa: E402
from app.auth.security import hash_password, normalize_email  # noqa: E402

SNAPSHOT = ROOT / "local_data" / "server_snapshot"
SQL_DUMP = SNAPSHOT / "remote_inventory_postgres.sql"
SNAPSHOT_MEDIA = SNAPSHOT / "media"
LOCAL_DATA = ROOT / "local_data"
LOCAL_DB = LOCAL_DATA / "inventory.sqlite3"
LOCAL_MEDIA = LOCAL_DATA / "media"


def parse_copy_blocks(path: Path) -> dict[str, tuple[list[str], list[dict[str, object]]]]:
    blocks: dict[str, tuple[list[str], list[dict[str, object]]]] = {}
    current_table: str | None = None
    current_columns: list[str] = []
    current_rows: list[dict[str, object]] = []

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if raw_line.startswith("COPY public."):
            prefix, _suffix = raw_line.split(" FROM stdin;", 1)
            table_and_columns = prefix.removeprefix("COPY public.")
            table_name, columns = table_and_columns.split(" (", 1)
            current_table = table_name
            current_columns = [column.strip() for column in columns.rstrip(")").split(",")]
            current_rows = []
            continue

        if current_table is None:
            continue

        if raw_line == r"\.":
            blocks[current_table] = (current_columns, current_rows)
            current_table = None
            current_columns = []
            current_rows = []
            continue

        values = next(csv.reader([raw_line], delimiter="\t", quoting=csv.QUOTE_NONE))
        row = {
            column: None if value == r"\N" else value.replace(r"\t", "\t").replace(r"\n", "\n").replace(r"\\", "\\")
            for column, value in zip(current_columns, values, strict=True)
        }
        current_rows.append(row)

    return blocks


def normalize_media_paths(rows: list[dict[str, object]]) -> None:
    for row in rows:
        stored_filename = row.get("stored_filename")
        if not stored_filename:
            continue
        row["original_path"] = str(LOCAL_MEDIA / "originals" / str(stored_filename))
        row["preview_path"] = str(LOCAL_MEDIA / "previews" / str(stored_filename))
        row["thumbnail_path"] = str(LOCAL_MEDIA / "thumbnails" / str(stored_filename))


def normalize_project_paths(rows: list[dict[str, object]]) -> None:
    for row in rows:
        image_path = row.get("image_path")
        if image_path:
            row["image_path"] = str(LOCAL_MEDIA / "projects" / Path(str(image_path)).name)


def normalize_local_admin(rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    admin = rows[0]
    admin["name"] = "admin"
    admin["email"] = "admin@tech-panda.local"
    admin["normalized_email"] = normalize_email(str(admin["email"]))
    admin["password_hash"] = hash_password("admin")
    admin["role"] = "owner"


def reset_local_storage() -> None:
    LOCAL_DATA.mkdir(parents=True, exist_ok=True)
    if LOCAL_DB.exists():
        LOCAL_DB.unlink()
    if LOCAL_MEDIA.exists():
        shutil.rmtree(LOCAL_MEDIA)
    if SNAPSHOT_MEDIA.exists():
        shutil.copytree(SNAPSHOT_MEDIA, LOCAL_MEDIA)
    else:
        LOCAL_MEDIA.mkdir(parents=True, exist_ok=True)


def coerce_rows_for_sqlite(table_name: str, rows: list[dict[str, object]]) -> list[dict[str, object]]:
    table = Base.metadata.tables[table_name]
    coerced_rows: list[dict[str, object]] = []
    for row in rows:
        coerced = {}
        for column in table.columns:
            value = row.get(column.name)
            if value is None:
                coerced[column.name] = None
            elif isinstance(column.type, Boolean):
                coerced[column.name] = value in {"t", "true", "True", "1", True}
            elif isinstance(column.type, Integer):
                coerced[column.name] = int(str(value))
            elif isinstance(column.type, Numeric):
                coerced[column.name] = Decimal(str(value))
            elif isinstance(column.type, DateTime):
                coerced[column.name] = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
            else:
                coerced[column.name] = value
        coerced_rows.append(coerced)
    return coerced_rows


def main() -> None:
    if not SQL_DUMP.exists():
        raise SystemExit(f"Missing dump: {SQL_DUMP}")

    blocks = parse_copy_blocks(SQL_DUMP)
    if "component_images" in blocks:
        normalize_media_paths(blocks["component_images"][1])
    if "projects" in blocks:
        normalize_project_paths(blocks["projects"][1])
    if "users" in blocks:
        normalize_local_admin(blocks["users"][1])

    reset_local_storage()
    engine = create_engine(f"sqlite:///{LOCAL_DB.as_posix()}", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    try:
        for table in Base.metadata.sorted_tables:
            block = blocks.get(table.name)
            if not block:
                continue
            rows = coerce_rows_for_sqlite(table.name, block[1])
            if rows:
                session.execute(insert(table), rows)
        session.commit()
    finally:
        session.close()

    print(f"Imported snapshot into {LOCAL_DB}")
    print(f"Copied media into {LOCAL_MEDIA}")


if __name__ == "__main__":
    main()
