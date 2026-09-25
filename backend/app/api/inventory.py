import csv
from datetime import datetime
from datetime import date, timedelta
from decimal import Decimal
import io
from pathlib import Path
import re
import shutil
from io import BytesIO
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, Response, UploadFile, status
from fastapi.encoders import jsonable_encoder
from sqlalchemy import func, or_, select
from sqlalchemy import case, func, or_, select
from sqlalchemy.orm import Session, selectinload
import qrcode
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

from app.auth.dependencies import require_roles
from app.core.config import get_settings
from app.database.session import get_db
from app.models import Category, Component, ComponentType, InventoryTransaction, InventoryTransactionLine, Location, Project, ProjectComponent, ProjectKit, ProjectKitLine, User
from app.models import Category, Component, ComponentType, InventoryTransaction, InventoryTransactionLine, Location, Project, ProjectComponent, Supplier, User
from app.schemas.common import (
    CategoryCreate,
    CategoryRead,
    ComponentCreate,
    ComponentRead,
    ComponentTypeCreate,
    ComponentTypeRead,
    ComponentTypeUpdate,
    ComponentUpdate,
    LocationCreate,
    LocationRead,
    LocationUpdate,
    ProjectCreate,
    ProjectComponentBatchUpdate,
    ProjectComponentRead,
    ProjectComponentUpdate,
    ProjectRead,
    ProjectUpdate,
    ProjectKitCreate,
    ProjectKitRead,
    ProjectKitUpdate,
    SupplierCreate,
    SupplierRead,
    SupplierUpdate,
    TransactionCreate,
    TransactionDetailRead,
    TransactionRead,
    TransactionUpdate,
)
from app.services.bootstrap import ensure_workspace
from app.services.inventory_service import build_component_search_text, create_component, create_transaction, get_workspace, normalize_text
from app.services.report_service import (
    build_inventory_csv,
    build_inventory_pdf,
    build_project_pdf,
)

router = APIRouter(tags=["inventory"])


@router.get("/alerts")
def get_stock_alerts(
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[dict]:
    """Return all components that are low-stock (qty <= minimum) or out-of-stock (qty <= 0)."""
    workspace = get_workspace(db)
    components = list(
        db.scalars(
            select(Component)
            .where(
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
            )
            .options(selectinload(Component.location))
        )
    )
    alerts = []
    today = date.today()
    expiry_cutoff = today + timedelta(days=30)
    for component in components:
        qty = Decimal(component.current_quantity)
        minimum = Decimal(component.minimum_quantity)
        if qty <= 0:
            alert_type = "out_of_stock"
        elif minimum > 0 and qty <= minimum:
            alert_type = "low_stock"
        elif component.expiry_date:
            try:
                expiry = date.fromisoformat(component.expiry_date[:10])
            except ValueError:
                expiry = None
            if expiry is not None and expiry < today:
                alert_type = "expired"
            elif expiry is not None and expiry <= expiry_cutoff:
                alert_type = "expiry_soon"
            else:
                continue
        else:
            continue
        alerts.append({
            "id": component.id,
            "inventory_code": component.inventory_code,
            "name": component.name,
            "current_quantity": str(component.current_quantity),
            "minimum_quantity": str(component.minimum_quantity),
            "unit": component.unit,
            "location_name": component.location_name,
            "primary_image_thumbnail": component.primary_image_thumbnail,
            "alert_type": alert_type,
            "expiry_date": component.expiry_date,
        })
    alerts.sort(key=lambda a: ({"expired": 0, "out_of_stock": 1, "expiry_soon": 2, "low_stock": 3}.get(a["alert_type"], 4), a["name"].lower()))
    return alerts



@router.get("/locations/labels.pdf")
def location_labels_pdf(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> Response:
    workspace = get_workspace(db)
    locations = list(db.scalars(select(Location).where(Location.workspace_id == workspace.id, Location.is_active.is_(True), Location.qr_code_value.is_not(None)).order_by(Location.display_name, Location.name)))
    output = BytesIO()
    pdf = canvas.Canvas(output, pagesize=letter)
    width, height = letter
    cols, rows = 3, 8
    cell_w, cell_h = width / cols, height / rows
    for index, location in enumerate(locations):
        slot = index % (cols * rows)
        if slot == 0 and index > 0:
            pdf.showPage()
        col, row = slot % cols, slot // cols
        x, y = col * cell_w, height - (row + 1) * cell_h
        qr = qrcode.make(location.qr_code_value).convert("RGB")
        image = BytesIO()
        qr.save(image, format="PNG")
        image.seek(0)
        from reportlab.lib.utils import ImageReader
        pdf.drawImage(ImageReader(image), x + 12, y + 24, width=cell_w - 24, height=cell_h - 48, preserveAspectRatio=True, anchor="c")
        pdf.setFont("Helvetica-Bold", 9)
        pdf.drawCentredString(x + cell_w / 2, y + 12, (location.display_name or location.name)[:42])
    if locations:
        pdf.showPage()
    pdf.save()
    return Response(content=output.getvalue(), media_type="application/pdf", headers={"Content-Disposition": "attachment; filename=location_qr_labels.pdf"})


@router.get("/categories", response_model=list[CategoryRead])
def list_categories(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> list[Category]:
    workspace = get_workspace(db)
    return list(db.scalars(select(Category).where(Category.workspace_id == workspace.id, Category.is_active.is_(True)).order_by(Category.display_order, Category.name)))


@router.post("/categories", response_model=CategoryRead)
def add_category(payload: CategoryCreate, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> Category:
    workspace = ensure_workspace(db)
    category = Category(
        workspace_id=workspace.id,
        name=payload.name.strip(),
        normalized_name=normalize_text(payload.name),
        code_prefix=payload.code_prefix.strip().upper(),
        description=payload.description,
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.get("/component-types", response_model=list[ComponentTypeRead])
def list_component_types(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> list[ComponentType]:
    workspace = get_workspace(db)
    return list(db.scalars(select(ComponentType).where(ComponentType.workspace_id == workspace.id, ComponentType.is_active.is_(True)).order_by(ComponentType.display_order, ComponentType.name)))


@router.post("/component-types", response_model=ComponentTypeRead)
def add_component_type(payload: ComponentTypeCreate, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> ComponentType:
    workspace = get_workspace(db)
    name = payload.name.strip()
    normalized_name = normalize_text(name)
    existing = db.scalar(
        select(ComponentType).where(
            ComponentType.workspace_id == workspace.id,
            ComponentType.normalized_name == normalized_name,
            ComponentType.is_active.is_(True),
        )
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Component type '{name}' already exists")
    parent_type_id = payload.parent_type_id.strip() if payload.parent_type_id else None
    if parent_type_id:
        parent = db.get(ComponentType, parent_type_id)
        if not parent or parent.workspace_id != workspace.id or not parent.is_active:
            raise HTTPException(status_code=400, detail="Parent component type not found")
    component_type = ComponentType(
        workspace_id=workspace.id,
        name=name,
        normalized_name=normalize_text(name),
        parent_type_id=parent_type_id,
        icon_svg=payload.icon_svg,
    )
    db.add(component_type)
    db.commit()
    db.refresh(component_type)
    return component_type


@router.patch("/component-types/{component_type_id}", response_model=ComponentTypeRead)
def update_component_type(
    component_type_id: str,
    payload: ComponentTypeUpdate,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> ComponentType:
    workspace = get_workspace(db)
    component_type = db.get(ComponentType, component_type_id)
    if not component_type or component_type.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Component type not found")
    old_name = component_type.name
    changes = payload.model_dump(exclude_unset=True)
    if "parent_type_id" in changes:
        parent_id = changes["parent_type_id"]
        if parent_id:
            parent_id = parent_id.strip()
            if parent_id == component_type.id:
                raise HTTPException(status_code=400, detail="A component type cannot be its own parent")
            parent = db.get(ComponentType, parent_id)
            if not parent or parent.workspace_id != workspace.id:
                raise HTTPException(status_code=400, detail="Parent component type not found")
            component_type.parent_type_id = parent_id
        else:
            component_type.parent_type_id = None
    if "name" in changes and changes["name"] is not None:
        component_type.name = changes["name"].strip()
        component_type.normalized_name = normalize_text(component_type.name)
        new_name = changes["name"].strip()
        normalized_name = normalize_text(new_name)
        existing = db.scalar(
            select(ComponentType).where(
                ComponentType.workspace_id == workspace.id,
                ComponentType.normalized_name == normalized_name,
                ComponentType.id != component_type.id,
                ComponentType.is_active.is_(True),
            )
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Component type '{new_name}' already exists")
        component_type.name = new_name
        component_type.normalized_name = normalized_name
        for component in db.scalars(select(Component).where(Component.workspace_id == workspace.id, Component.package_type == old_name)):
            component.package_type = component_type.name
            component.search_text = build_component_search_text(component)
    if "icon_svg" in changes:
        component_type.icon_svg = changes["icon_svg"]
    if "is_active" in changes and changes["is_active"] is not None:
        component_type.is_active = changes["is_active"]
    db.commit()
    db.refresh(component_type)
    return component_type


@router.delete("/component-types/{component_type_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_component_type(
    component_type_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    component_type = db.get(ComponentType, component_type_id)
    if not component_type or component_type.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Component type not found")

    used_count = db.scalar(
        select(func.count(Component.id)).where(
            Component.workspace_id == workspace.id,
            Component.package_type == component_type.name,
            Component.is_archived.is_(False),
        )
    )
    if used_count and used_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete component type '{component_type.name}': {used_count} component(s) are assigned to it.",
        )

    child_count = db.scalar(
        select(func.count(ComponentType.id)).where(
            ComponentType.workspace_id == workspace.id,
            ComponentType.parent_type_id == component_type.id,
            ComponentType.is_active.is_(True),
        )
    )
    if child_count and child_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete component type '{component_type.name}': {child_count} sub-type(s) depend on it.",
        )

    component_type.is_active = False
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/locations", response_model=list[LocationRead])
def list_locations(
    qr_code_value: str | None = Query(default=None),
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[Location]:
    workspace = get_workspace(db)
    stmt = select(Location).where(Location.workspace_id == workspace.id, Location.is_active.is_(True))
    if qr_code_value:
        clean_qr = qr_code_value.strip()
        loc_id = clean_qr.removeprefix("location:")
        stmt = stmt.where(or_(Location.qr_code_value == clean_qr, Location.id == loc_id))
    return list(db.scalars(stmt.order_by(Location.name, Location.cabinet, Location.shelf, Location.drawer, Location.box, Location.bin)))


@router.post("/locations", response_model=LocationRead)
def add_location(payload: LocationCreate, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> Location:
    workspace = get_workspace(db)
    location = Location(workspace_id=workspace.id, **{key: value.strip() if isinstance(value, str) else value for key, value in payload.model_dump().items()})
    name = payload.name.strip()
    existing = db.scalar(
        select(Location).where(
            Location.workspace_id == workspace.id,
            func.lower(Location.name) == name.lower(),
            Location.is_active.is_(True),
        )
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Location '{name}' already exists")
    data = payload.model_dump()
    generate_qr = data.pop("generate_qr_code", False)
    location = Location(
        workspace_id=workspace.id,
        **{key: value.strip() if isinstance(value, str) else value for key, value in data.items() if value is not None}
    )
    db.add(location)
    db.flush()
    if generate_qr and not location.qr_code_value:
        location.qr_code_value = f"location:{location.id}"
    db.commit()
    db.refresh(location)
    return location


@router.patch("/locations/{location_id}", response_model=LocationRead)
def update_location(location_id: str, payload: LocationUpdate, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> Location:
    workspace = get_workspace(db)
    location = db.get(Location, location_id)
    if not location or location.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Location not found")
    changes = payload.model_dump(exclude_unset=True)
    if "name" in changes and changes["name"] is not None:
        new_name = changes["name"].strip()
        existing = db.scalar(
            select(Location).where(
                Location.workspace_id == workspace.id,
                func.lower(Location.name) == new_name.lower(),
                Location.id != location.id,
                Location.is_active.is_(True),
            )
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Location '{new_name}' already exists")
        changes["name"] = new_name
    generate_qr = changes.pop("generate_qr_code", None)
    if generate_qr is True:
        location.qr_code_value = f"location:{location.id}"
    elif generate_qr is False:
        location.qr_code_value = None
    for key, value in changes.items():
        setattr(location, key, value.strip() if isinstance(value, str) else value)
    db.commit()
    db.refresh(location)
    return location


@router.delete("/locations/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_location(
    location_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    location = db.get(Location, location_id)
    if not location or location.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Location not found")

    used_count = db.scalar(
        select(func.count(Component.id)).where(
            Component.workspace_id == workspace.id,
            Component.location_id == location.id,
            Component.is_archived.is_(False),
        )
    )
    if used_count and used_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete location '{location.name}': {used_count} component(s) are stored here.",
        )

    child_count = db.scalar(
        select(func.count(Location.id)).where(
            Location.workspace_id == workspace.id,
            Location.parent_location_id == location.id,
            Location.is_active.is_(True),
        )
    )
    if child_count and child_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot delete location '{location.name}': {child_count} sub-location(s) depend on it.",
        )

    location.is_active = False
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/suppliers", response_model=list[SupplierRead])
def list_suppliers(
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[Supplier]:
    workspace = get_workspace(db)
    return list(
        db.scalars(
            select(Supplier)
            .where(
                Supplier.workspace_id == workspace.id,
                Supplier.is_active.is_(True),
            )
            .order_by(Supplier.name)
        )
    )


@router.post("/suppliers", response_model=SupplierRead)
def add_supplier(
    payload: SupplierCreate,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Supplier:
    workspace = get_workspace(db)
    name = payload.name.strip()
    existing = db.scalar(
        select(Supplier).where(
            Supplier.workspace_id == workspace.id,
            func.lower(Supplier.name) == name.lower(),
            Supplier.is_active.is_(True),
        )
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Supplier '{name}' already exists")
    supplier = Supplier(
        workspace_id=workspace.id,
        name=name,
        website=payload.website.strip() if payload.website else None,
        contact=payload.contact.strip() if payload.contact else None,
        notes=payload.notes.strip() if payload.notes else None,
        is_active=True,
    )
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.patch("/suppliers/{supplier_id}", response_model=SupplierRead)
def update_supplier(
    supplier_id: str,
    payload: SupplierUpdate,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Supplier:
    workspace = get_workspace(db)
    supplier = db.get(Supplier, supplier_id)
    if not supplier or supplier.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Supplier not found")
    changes = payload.model_dump(exclude_unset=True)
    if "name" in changes and changes["name"] is not None:
        new_name = changes["name"].strip()
        existing = db.scalar(
            select(Supplier).where(
                Supplier.workspace_id == workspace.id,
                func.lower(Supplier.name) == new_name.lower(),
                Supplier.id != supplier.id,
                Supplier.is_active.is_(True),
            )
        )
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Supplier '{new_name}' already exists")
        changes["name"] = new_name
    for key, value in changes.items():
        setattr(supplier, key, value.strip() if isinstance(value, str) else value)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.delete("/suppliers/{supplier_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_supplier(
    supplier_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    supplier = db.get(Supplier, supplier_id)
    if not supplier or supplier.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Supplier not found")
    supplier.is_active = False
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/components", response_model=list[ComponentRead])
def list_components(
    q: str | None = Query(default=None),
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[Component]:
    workspace = get_workspace(db)
    stmt = (
        select(Component)
        .where(
            Component.workspace_id == workspace.id,
            Component.is_archived.is_(False),
        )
        .options(
            selectinload(Component.transaction_lines),
            selectinload(Component.project_lines),
            selectinload(Component.supplier),
        )
    )
    if q:
        like = f"%{normalize_text(q)}%"
        stmt = stmt.where(or_(Component.search_text.ilike(like), Component.inventory_code.ilike(like), Component.barcode.ilike(like)))
    return list(db.scalars(stmt.order_by(Component.name).limit(limit)))


@router.post("/components", response_model=ComponentRead)
def add_component(payload: ComponentCreate, db: Session = Depends(get_db), user: User = Depends(require_roles("owner", "editor"))) -> Component:
    return create_component(db, payload, user.id)


@router.get("/components/{component_id}", response_model=ComponentRead)
def get_component(component_id: str, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> Component:
    workspace = get_workspace(db)
    component = db.get(Component, component_id)
    if not component or component.workspace_id != workspace.id or component.is_archived:
        raise HTTPException(status_code=404, detail="Component not found")
    return component


@router.patch("/components/{component_id}", response_model=ComponentRead)
def update_component(
    component_id: str,
    payload: ComponentUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Component:
    workspace = get_workspace(db)
    component = db.get(Component, component_id)
    if not component or component.workspace_id != workspace.id or component.is_archived:
        raise HTTPException(status_code=404, detail="Component not found")

    changes = payload.model_dump(exclude_unset=True)
    if "name" in changes and changes["name"] is not None:
        component.name = changes["name"].strip()
        component.normalized_name = normalize_text(component.name)
        new_name = changes["name"].strip()
        normalized_name = normalize_text(new_name)
        duplicate = db.scalar(
            select(Component).where(
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
                Component.normalized_name == normalized_name,
                Component.id != component.id,
            )
        )
        if duplicate:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Component '{new_name}' already exists as {duplicate.inventory_code}")
        component.name = new_name
        component.normalized_name = normalized_name
    if "package_type" in changes:
        value = changes["package_type"]
        component.package_type = value.strip() if value else None
    if "manufacturer" in changes:
        value = changes["manufacturer"]
        component.manufacturer = value.strip() if value else None
    if "description" in changes:
        value = changes["description"]
        component.description = value.strip() if value else None
    if "unit" in changes and changes["unit"] is not None:
        component.unit = changes["unit"].strip() or "Pieces"
    if "location_id" in changes:
        value = changes["location_id"]
        if value:
            location = db.get(Location, value)
            if not location or location.workspace_id != workspace.id or not location.is_active:
                raise HTTPException(status_code=404, detail="Location not found")
            component.location_id = location.id
        else:
            component.location_id = None
    if "supplier_id" in changes:
        value = changes["supplier_id"]
        if value:
            supplier = db.get(Supplier, value)
            if not supplier or supplier.workspace_id != workspace.id or not supplier.is_active:
                raise HTTPException(status_code=404, detail="Supplier not found")
            component.supplier_id = supplier.id
        else:
            component.supplier_id = None
    if "price" in changes:
        component.price = changes["price"]
        component.unit_cost_minor = int(round(changes["price"] * 100)) if changes["price"] is not None else None
    if "datasheet_url" in changes:
        value = changes["datasheet_url"]
        component.datasheet_url = value.strip() if isinstance(value, str) and value.strip() else None
    if "datasheet_text" in changes:
        value = changes["datasheet_text"]
        component.datasheet_text = value.strip() if isinstance(value, str) and value.strip() else None
    if "expiry_date" in changes:
        value = changes["expiry_date"]
        component.expiry_date = value.strip() if isinstance(value, str) and value.strip() else None

    component.search_text = build_component_search_text(component)
    component.updated_by = user.id
    db.commit()
    db.refresh(component)
    return component


ALLOWED_DATASHEET_EXTENSIONS = {
    ".pdf", ".txt", ".doc", ".docx", ".rtf", ".csv", ".tsv", ".png", ".jpg", ".jpeg"
}


@router.post("/components/{component_id}/datasheet", response_model=ComponentRead)
def upload_component_datasheet(
    component_id: str,
    upload: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Component:
    workspace = get_workspace(db)
    component = db.get(Component, component_id)
    if not component or component.workspace_id != workspace.id or component.is_archived:
        raise HTTPException(status_code=404, detail="Component not found")
    suffix = Path(upload.filename or "datasheet.pdf").suffix.lower() or ".pdf"
    if suffix not in ALLOWED_DATASHEET_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{suffix}'. Allowed: PDF, TXT, DOC, DOCX, RTF, CSV, Images.",
        )
    settings = get_settings()
    datasheets_dir = Path(settings.media_root) / "datasheets"
    datasheets_dir.mkdir(parents=True, exist_ok=True)
    stored = f"{uuid4()}{suffix}"
    dest_path = datasheets_dir / stored
    with dest_path.open("wb") as fh:
        shutil.copyfileobj(upload.file, fh)

    if component.datasheet_url and component.datasheet_url.startswith("/api/v1/media/datasheets/"):
        old_name = component.datasheet_url.split("/")[-1]
        old_path = datasheets_dir / old_name
        try:
            old_path.unlink(missing_ok=True)
        except OSError:
            pass

    component.datasheet_url = f"/api/v1/media/datasheets/{stored}"
    component.updated_by = user.id
    db.commit()
    db.refresh(component)
    return component


@router.delete("/components/{component_id}/datasheet", response_model=ComponentRead)
def delete_component_datasheet(
    component_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Component:
    workspace = get_workspace(db)
    component = db.get(Component, component_id)
    if not component or component.workspace_id != workspace.id or component.is_archived:
        raise HTTPException(status_code=404, detail="Component not found")
    if component.datasheet_url and component.datasheet_url.startswith("/api/v1/media/datasheets/"):
        settings = get_settings()
        old_name = component.datasheet_url.split("/")[-1]
        old_path = Path(settings.media_root) / "datasheets" / old_name
        try:
            old_path.unlink(missing_ok=True)
        except OSError:
            pass
    component.datasheet_url = None
    component.updated_by = user.id
    db.commit()
    db.refresh(component)
    return component


@router.delete("/components/{component_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_component(
    component_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    component = db.get(Component, component_id)
    if not component or component.workspace_id != workspace.id or component.is_archived:
        raise HTTPException(status_code=404, detail="Component not found")

    allocated_project = db.scalar(
        select(ProjectComponent.id).where(
            ProjectComponent.component_id == component.id,
        )
    )
    if allocated_project:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Component is used by a project. Remove it from the project first.",
        )
    inventory_movement = db.scalar(
        select(InventoryTransactionLine.id).where(
            InventoryTransactionLine.component_id == component.id,
        )
    )
    if inventory_movement:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Component has stock movement history and cannot be deleted. "
                "Delete its stock movements first."
            ),
        )

    component.is_archived = True
    component.updated_by = user.id
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/transactions", response_model=TransactionRead)
def post_transaction(payload: TransactionCreate, db: Session = Depends(get_db), user: User = Depends(require_roles("owner", "editor"))) -> InventoryTransaction:
    tx = create_transaction(db, payload, user.id)
    db.commit()
    db.refresh(tx)
    return tx


@router.get("/transactions", response_model=list[TransactionRead])
def list_transactions(page: int = Query(1, ge=1), limit: int = Query(25, ge=1, le=100), before: datetime | None = Query(None), after: datetime | None = Query(None), component_id: str | None = Query(None), db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> list[InventoryTransaction]:
    workspace = get_workspace(db)
    query = select(InventoryTransaction).where(InventoryTransaction.workspace_id == workspace.id)
    if before is not None: query = query.where(InventoryTransaction.created_at < before)
    if after is not None: query = query.where(InventoryTransaction.created_at > after)
    if component_id: query = query.join(InventoryTransactionLine).where(InventoryTransactionLine.component_id == component_id).distinct()
    query = query.order_by(InventoryTransaction.created_at.desc())
    if before is None and after is None: query = query.offset((page - 1) * limit)
    return list(db.scalars(query.limit(limit)))


def _transaction_detail_query(transaction_id: str):
    return (
        select(InventoryTransaction)
        .where(InventoryTransaction.id == transaction_id)
        .options(
            selectinload(InventoryTransaction.lines)
            .selectinload(InventoryTransactionLine.component)
            .selectinload(Component.images),
            selectinload(InventoryTransaction.lines)
            .selectinload(InventoryTransactionLine.component)
            .selectinload(Component.location),
        )
    )


def _get_workspace_transaction(
    db: Session,
    transaction_id: str,
    workspace_id: str,
) -> InventoryTransaction:
    transaction = db.scalar(_transaction_detail_query(transaction_id))
    if not transaction or transaction.workspace_id != workspace_id:
        raise HTTPException(status_code=404, detail="Stock movement not found")
    return transaction


def _require_manual_transaction(transaction: InventoryTransaction) -> None:
    if transaction.project_id is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Project-generated movements are managed from their project "
                "and cannot be edited or deleted here."
            ),
        )


@router.get(
    "/transactions/{transaction_id}",
    response_model=TransactionDetailRead,
)
def get_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> InventoryTransaction:
    workspace = get_workspace(db)
    return _get_workspace_transaction(db, transaction_id, workspace.id)


@router.put(
    "/transactions/{transaction_id}",
    response_model=TransactionDetailRead,
)
def update_transaction(
    transaction_id: str,
    payload: TransactionUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> InventoryTransaction:
    workspace = get_workspace(db)
    transaction = _get_workspace_transaction(db, transaction_id, workspace.id)
    _require_manual_transaction(transaction)

    requested_ids = [line.component_id for line in payload.lines]
    if len(requested_ids) != len(set(requested_ids)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A component can only appear once in a stock movement.",
        )
    old_ids = {line.component_id for line in transaction.lines}
    impacted_ids = old_ids | set(requested_ids)
    components = {
        component.id: component
        for component in db.scalars(
            select(Component)
            .where(
                Component.id.in_(impacted_ids),
                Component.workspace_id == workspace.id,
            )
            .with_for_update()
        )
    }
    if len(components) != len(impacted_ids):
        raise HTTPException(status_code=404, detail="Component not found")
    if any(components[component_id].is_archived for component_id in requested_ids):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Archived components cannot be added to a stock movement.",
        )

    old_deltas: dict[str, Decimal] = {}
    for line in transaction.lines:
        old_deltas[line.component_id] = (
            old_deltas.get(line.component_id, Decimal("0"))
            + Decimal(line.quantity_delta)
        )
    running = {
        component_id: Decimal(component.current_quantity)
        - old_deltas.get(component_id, Decimal("0"))
        for component_id, component in components.items()
    }
    multiplier = (
        Decimal("1")
        if payload.transaction_type in {"stock_in", "return", "adjustment"}
        else Decimal("-1")
    )
    new_lines: list[InventoryTransactionLine] = []
    for requested_line in payload.lines:
        component = components[requested_line.component_id]
        before = running[component.id]
        delta = Decimal(requested_line.quantity) * multiplier
        after = before + delta
        if after < 0 and not workspace.allow_negative_stock:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Insufficient stock for {component.inventory_code}",
            )
        running[component.id] = after
        new_lines.append(
            InventoryTransactionLine(
                transaction_id=transaction.id,
                component_id=component.id,
                quantity_delta=delta,
                quantity_before=before,
                quantity_after=after,
                unit=component.unit,
                unit_cost_minor=requested_line.unit_cost_minor,
                line_notes=requested_line.notes,
            )
        )

    for component_id, quantity in running.items():
        if quantity < 0 and not workspace.allow_negative_stock:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"Insufficient stock for "
                    f"{components[component_id].inventory_code}"
                ),
            )
        components[component_id].current_quantity = quantity
        components[component_id].updated_by = user.id
    for old_line in list(transaction.lines):
        db.delete(old_line)
    db.flush()
    for new_line in new_lines:
        db.add(new_line)

    transaction.transaction_type = payload.transaction_type
    transaction.reason = payload.reason
    transaction.notes = payload.notes
    transaction.line_count = len(payload.lines)
    transaction.total_quantity = sum(
        (Decimal(line.quantity) for line in payload.lines),
        Decimal("0"),
    )
    db.commit()
    db.expire(transaction, ["lines"])
    return _get_workspace_transaction(db, transaction_id, workspace.id)


@router.delete(
    "/transactions/{transaction_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_transaction(
    transaction_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    transaction = _get_workspace_transaction(db, transaction_id, workspace.id)
    _require_manual_transaction(transaction)
    component_ids = {line.component_id for line in transaction.lines}
    components = {
        component.id: component
        for component in db.scalars(
            select(Component)
            .where(
                Component.id.in_(component_ids),
                Component.workspace_id == workspace.id,
            )
            .with_for_update()
        )
    }
    if len(components) != len(component_ids):
        raise HTTPException(status_code=404, detail="Component not found")

    old_deltas: dict[str, Decimal] = {}
    for line in transaction.lines:
        old_deltas[line.component_id] = (
            old_deltas.get(line.component_id, Decimal("0"))
            + Decimal(line.quantity_delta)
        )
    for component_id, component in components.items():
        after = Decimal(component.current_quantity) - old_deltas[component_id]
        if after < 0 and not workspace.allow_negative_stock:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"Cannot delete this movement because "
                    f"{component.inventory_code} no longer has enough stock."
                ),
            )
        component.current_quantity = after
        component.updated_by = user.id

    db.delete(transaction)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/projects", response_model=ProjectRead)
def add_project(payload: ProjectCreate, db: Session = Depends(get_db), user: User = Depends(require_roles("owner", "editor"))) -> Project:
    workspace = get_workspace(db)
    project = Project(workspace_id=workspace.id, created_by=user.id, **payload.model_dump())
    data = payload.model_dump()
    if data.get("status") == "Planned":
        data["status"] = "To Do"
    project = Project(workspace_id=workspace.id, created_by=user.id, **data)
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.get("/projects", response_model=list[ProjectRead])
def list_projects(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> list[Project]:
    workspace = get_workspace(db)
    status_order = case(
        (Project.status == "To Do", 1),
        (Project.status == "In Progress", 2),
        (Project.status == "Completed", 3),
        else_=4,
    )
    projects = list(
        db.scalars(
            select(Project)
            .where(Project.workspace_id == workspace.id, Project.is_archived.is_(False))
            .options(
                selectinload(Project.components).selectinload(ProjectComponent.component)
            )
            .order_by(status_order, func.lower(Project.name))
        )
    )
    for p in projects:
        if p.status == "Planned":
            p.status = "To Do"
    return projects


def _project_kit_read(db: Session, kit: ProjectKit) -> dict:
    rows = db.execute(
        select(ProjectKitLine, Component.inventory_code, Component.name)
        .join(Component, Component.id == ProjectKitLine.component_id)
        .where(ProjectKitLine.project_kit_id == kit.id)
    ).all()
    return {
        "id": kit.id, "workspace_id": kit.workspace_id, "name": kit.name,
        "description": kit.description, "is_favorite": kit.is_favorite,
        "created_at": kit.created_at, "updated_at": kit.updated_at,
        "lines": [
            {"id": line.id, "project_kit_id": line.project_kit_id, "component_id": line.component_id,
             "quantity": line.quantity, "unit": line.unit, "notes": line.notes,
             "inventory_code": code, "component_name": name}
            for line, code, name in rows
        ],
    }


def _replace_kit_lines(db: Session, kit: ProjectKit, lines, workspace_id: str) -> None:
    component_ids = [line.component_id for line in lines]
    if len(component_ids) != len(set(component_ids)):
        raise HTTPException(status_code=422, detail="A component can only appear once in a kit.")
    valid = set(db.scalars(select(Component.id).where(Component.id.in_(component_ids), Component.workspace_id == workspace_id, Component.is_archived.is_(False))))
    if len(valid) != len(component_ids):
        raise HTTPException(status_code=404, detail="Component not found")
    db.query(ProjectKitLine).filter(ProjectKitLine.project_kit_id == kit.id).delete(synchronize_session=False)
    for line in lines:
        db.add(ProjectKitLine(project_kit_id=kit.id, component_id=line.component_id, quantity=line.quantity, unit=line.unit, notes=line.notes))


@router.get("/project-kits", response_model=list[ProjectKitRead])
def list_project_kits(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> list[dict]:
    workspace = get_workspace(db)
    kits = list(db.scalars(select(ProjectKit).where(ProjectKit.workspace_id == workspace.id).order_by(ProjectKit.is_favorite.desc(), ProjectKit.name)))
    return [_project_kit_read(db, kit) for kit in kits]


@router.post("/project-kits", response_model=ProjectKitRead)
def create_project_kit(payload: ProjectKitCreate, db: Session = Depends(get_db), user: User = Depends(require_roles("owner", "editor"))) -> dict:
    workspace = get_workspace(db)
    kit = ProjectKit(workspace_id=workspace.id, name=payload.name.strip(), description=payload.description, is_favorite=payload.is_favorite)
    db.add(kit)
    db.flush()
    _replace_kit_lines(db, kit, payload.lines, workspace.id)
    db.commit()
    db.refresh(kit)
    return _project_kit_read(db, kit)


@router.patch("/project-kits/{kit_id}", response_model=ProjectKitRead)
def update_project_kit(kit_id: str, payload: ProjectKitUpdate, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> dict:
    workspace = get_workspace(db)
    kit = db.scalar(select(ProjectKit).where(ProjectKit.id == kit_id, ProjectKit.workspace_id == workspace.id))
    if not kit:
        raise HTTPException(status_code=404, detail="Project kit not found")
    if payload.name is not None: kit.name = payload.name.strip()
    if payload.description is not None: kit.description = payload.description
    if payload.is_favorite is not None: kit.is_favorite = payload.is_favorite
    if payload.lines is not None: _replace_kit_lines(db, kit, payload.lines, workspace.id)
    db.commit()
    db.refresh(kit)
    return _project_kit_read(db, kit)


@router.delete("/project-kits/{kit_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project_kit(kit_id: str, db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor"))) -> Response:
    workspace = get_workspace(db)
    kit = db.scalar(select(ProjectKit).where(ProjectKit.id == kit_id, ProjectKit.workspace_id == workspace.id))
    if not kit: raise HTTPException(status_code=404, detail="Project kit not found")
    db.delete(kit)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch("/projects/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor")),
    user: User = Depends(require_roles("owner", "editor")),
) -> Project:
    workspace = get_workspace(db)
    project = _get_active_project(db, project_id, workspace.id)
    old_status = "To Do" if project.status == "Planned" else project.status

    if "name" in payload.model_fields_set and payload.name is not None:
        project.name = payload.name.strip()
    if "project_type" in payload.model_fields_set and payload.project_type is not None:
        project.project_type = payload.project_type.strip()
    if "description" in payload.model_fields_set:
        description = payload.description.strip() if payload.description else None
        project.description = description or None

    if "status" in payload.model_fields_set and payload.status is not None:
        new_status = payload.status.strip()
        if new_status == "Planned":
            new_status = "To Do"
        project.status = new_status

        was_active = old_status in {"In Progress", "Completed"}
        now_active = new_status in {"In Progress", "Completed"}

        if not was_active and now_active:
            # Moving from To Do -> In Progress/Completed: deduct stock
            stock_out_lines = [
                {
                    "component_id": pc.component_id,
                    "quantity": Decimal(str(pc.quantity)),
                    "notes": f"Project '{project.name}' moved to {new_status}",
                }
                for pc in project.components
                if pc.quantity > 0
            ]
            if stock_out_lines:
                create_transaction(
                    db,
                    TransactionCreate(
                        transaction_type="stock_out",
                        idempotency_key=f"project-status-out-{project.id}-{uuid4()}",
                        project_id=project.id,
                        reason=f"Project status changed to {new_status}",
                        lines=stock_out_lines,
                    ),
                    user.id,
                )
        elif was_active and not now_active:
            # Moving from In Progress/Completed -> To Do: return stock
            return_lines = [
                {
                    "component_id": pc.component_id,
                    "quantity": Decimal(str(pc.quantity)),
                    "notes": f"Project '{project.name}' reverted to {new_status}",
                }
                for pc in project.components
                if pc.quantity > 0
            ]
            if return_lines:
                create_transaction(
                    db,
                    TransactionCreate(
                        transaction_type="return",
                        idempotency_key=f"project-status-return-{project.id}-{uuid4()}",
                        project_id=project.id,
                        reason=f"Project status reverted to {new_status}",
                        lines=return_lines,
                    ),
                    user.id,
                )

    db.commit()
    db.refresh(project)
    return project


def _get_active_project(db: Session, project_id: str, workspace_id: str) -> Project:
    project = db.scalar(
        select(Project)
        .where(Project.id == project_id, Project.workspace_id == workspace_id, Project.is_archived.is_(False))
        .options(
            selectinload(Project.components).selectinload(ProjectComponent.component)
        )
    )
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.status == "Planned":
        project.status = "To Do"
    return project


@router.get("/projects/{project_id}/components", response_model=list[ProjectComponentRead])
def list_project_components(
    project_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[ProjectComponent]:
    workspace = get_workspace(db)
    _get_active_project(db, project_id, workspace.id)
    stmt = (
        select(ProjectComponent)
        .where(ProjectComponent.project_id == project_id)
        .options(
            selectinload(ProjectComponent.component).selectinload(Component.images),
            selectinload(ProjectComponent.component).selectinload(Component.location),
        )
        .order_by(ProjectComponent.created_at, ProjectComponent.id)
    )
    return list(db.scalars(stmt))


@router.get("/projects/{project_id}/report.pdf")
def project_pdf(
    project_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> Response:
    workspace = get_workspace(db)
    project = _get_active_project(db, project_id, workspace.id)
    stmt = (
        select(ProjectComponent)
        .where(ProjectComponent.project_id == project_id)
        .options(
            selectinload(ProjectComponent.component).selectinload(Component.images),
            selectinload(ProjectComponent.component).selectinload(Component.location),
        )
        .order_by(ProjectComponent.created_at, ProjectComponent.id)
    )
    project_components = list(db.scalars(stmt))
    filename_stem = re.sub(r"[^A-Za-z0-9_-]+", "-", project.name).strip("-")
    filename = f"{(filename_stem or 'project')[:80]}.pdf"
    return Response(
        content=build_project_pdf(project, project_components),
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.put(
    "/projects/{project_id}/components",
    response_model=list[ProjectComponentRead],
)
def replace_project_components(
    project_id: str,
    payload: ProjectComponentBatchUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> list[ProjectComponent]:
    workspace = get_workspace(db)
    project = _get_active_project(db, project_id, workspace.id)
    component_ids = [line.component_id for line in payload.lines]
    if len(component_ids) != len(set(component_ids)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="A component can only appear once in a project.",
        )

    components = {
        component.id: component
        for component in db.scalars(
            select(Component)
            .where(
                Component.id.in_(component_ids),
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
            )
            .with_for_update()
        )
    }
    if len(components) != len(component_ids):
        raise HTTPException(status_code=404, detail="Component not found")

    existing = {
        line.component_id: line
        for line in db.scalars(
            select(ProjectComponent).where(
                ProjectComponent.project_id == project_id,
            )
        )
    }
    requested = {line.component_id: line for line in payload.lines}
    stock_out_lines: list[dict] = []
    return_lines: list[dict] = []

    for component_id in set(existing) | set(requested):
        old_quantity = (
            Decimal(existing[component_id].quantity)
            if component_id in existing
            else Decimal("0")
        )
        new_quantity = (
            Decimal(requested[component_id].quantity)
            if component_id in requested
            else Decimal("0")
        )
        difference = new_quantity - old_quantity
        movement = {
            "component_id": component_id,
            "quantity": abs(difference),
            "notes": (
                f"Project allocation changed from {old_quantity} "
                f"to {new_quantity}"
            ),
        }
        if difference > 0:
            stock_out_lines.append(movement)
        elif difference < 0:
            return_lines.append(movement)

    is_active = project.status in {"In Progress", "Completed"}
    if is_active:
        if return_lines:
            create_transaction(
                db,
                TransactionCreate(
                    transaction_type="return",
                    idempotency_key=f"project-batch-return-{project_id}-{uuid4()}",
                    project_id=project_id,
                    reason="Project components updated",
                    lines=return_lines,
                ),
                user.id,
            )
        if stock_out_lines:
            create_transaction(
                db,
                TransactionCreate(
                    transaction_type="stock_out",
                    idempotency_key=f"project-batch-out-{project_id}-{uuid4()}",
                    project_id=project_id,
                    reason="Project components updated",
                    lines=stock_out_lines,
                ),
                user.id,
            )

    for component_id, project_component in existing.items():
        if component_id not in requested:
            db.delete(project_component)
    for component_id, requested_line in requested.items():
        component = components[component_id]
        project_component = existing.get(component_id)
        if project_component:
            project_component.quantity = requested_line.quantity
            project_component.unit = component.unit
            project_component.notes = requested_line.notes
            project_component.updated_by = user.id
        else:
            db.add(
                ProjectComponent(
                    project_id=project_id,
                    component_id=component_id,
                    quantity=requested_line.quantity,
                    unit=component.unit,
                    notes=requested_line.notes,
                    created_by=user.id,
                    updated_by=user.id,
                )
            )

    db.commit()
    return list_project_components(project_id, db, user)


@router.put(
    "/projects/{project_id}/components/{component_id}",
    response_model=ProjectComponentRead,
)
def set_project_component(
    project_id: str,
    component_id: str,
    payload: ProjectComponentUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> ProjectComponent:
    workspace = get_workspace(db)
    _get_active_project(db, project_id, workspace.id)
    project = _get_active_project(db, project_id, workspace.id)
    component = db.scalar(
        select(Component)
        .where(
            Component.id == component_id,
            Component.workspace_id == workspace.id,
            Component.is_archived.is_(False),
        )
        .with_for_update()
    )
    if not component:
        raise HTTPException(status_code=404, detail="Component not found")

    project_component = db.scalar(
        select(ProjectComponent)
        .where(
            ProjectComponent.project_id == project_id,
            ProjectComponent.component_id == component_id,
        )
        .options(
            selectinload(ProjectComponent.component).selectinload(Component.images),
            selectinload(ProjectComponent.component).selectinload(Component.location),
        )
    )
    old_quantity = Decimal(project_component.quantity) if project_component else Decimal("0")
    new_quantity = Decimal(payload.quantity)
    difference = new_quantity - old_quantity

    is_active = project.status in {"In Progress", "Completed"}
    if is_active and difference != 0:
        create_transaction(
            db,
            TransactionCreate(
                transaction_type="stock_out" if difference > 0 else "return",
                idempotency_key=f"project-{project_id}-{uuid4()}",
                project_id=project_id,
                reason="Project component quantity changed",
                lines=[
                    {
                        "component_id": component_id,
                        "quantity": abs(difference),
                        "notes": f"Project allocation changed from {old_quantity} to {new_quantity}",
                    }
                ],
            ),
            user.id,
        )

    if project_component:
        project_component.quantity = new_quantity
        project_component.notes = payload.notes
        project_component.unit = component.unit
        project_component.updated_by = user.id
    else:
        project_component = ProjectComponent(
            project_id=project_id,
            component_id=component_id,
            quantity=new_quantity,
            unit=component.unit,
            notes=payload.notes,
            created_by=user.id,
            updated_by=user.id,
            component=component,
        )
        db.add(project_component)

    db.commit()
    db.refresh(project_component)
    return project_component


@router.delete(
    "/projects/{project_id}/components/{component_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_project_component(
    project_id: str,
    component_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> Response:
    workspace = get_workspace(db)
    _get_active_project(db, project_id, workspace.id)
    project = _get_active_project(db, project_id, workspace.id)
    project_component = db.scalar(
        select(ProjectComponent).where(
            ProjectComponent.project_id == project_id,
            ProjectComponent.component_id == component_id,
        )
    )
    if not project_component:
        raise HTTPException(status_code=404, detail="Project component not found")

    create_transaction(
        db,
        TransactionCreate(
            transaction_type="return",
            idempotency_key=f"project-remove-{project_component.id}-{uuid4()}",
            project_id=project_id,
            reason="Component removed from project",
            lines=[
                {
                    "component_id": component_id,
                    "quantity": Decimal(project_component.quantity),
                    "notes": "Returned after removal from project",
                }
            ],
        ),
        user.id,
    )
    is_active = project.status in {"In Progress", "Completed"}
    if is_active:
        create_transaction(
            db,
            TransactionCreate(
                transaction_type="return",
                idempotency_key=f"project-remove-{project_component.id}-{uuid4()}",
                project_id=project_id,
                reason="Component removed from project",
                lines=[
                    {
                        "component_id": component_id,
                        "quantity": Decimal(project_component.quantity),
                        "notes": "Returned after removal from project",
                    }
                ],
            ),
            user.id,
        )
    db.delete(project_component)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/projects/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> None:
    workspace = get_workspace(db)
    project = db.scalar(
        select(Project)
        .where(Project.id == project_id, Project.workspace_id == workspace.id, Project.is_archived.is_(False))
        .options(
            selectinload(Project.components)
        )
    )
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    is_active = project.status in {"In Progress", "Completed"}
    if is_active and project.components:
        return_lines = [
            {
                "component_id": pc.component_id,
                "quantity": Decimal(str(pc.quantity)),
                "notes": f"Returned after project '{project.name}' removal",
            }
            for pc in project.components
            if pc.quantity > 0
        ]
        if return_lines:
            create_transaction(
                db,
                TransactionCreate(
                    transaction_type="return",
                    idempotency_key=f"project-delete-return-{project.id}-{uuid4()}",
                    project_id=project.id,
                    reason="Project removed",
                    lines=return_lines,
                ),
                user.id,
            )

    project.is_archived = True
    db.commit()


@router.get("/reorder-list")
def reorder_list(
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> list[dict]:
    """Return active components whose stock is below their reorder minimum."""
    workspace = get_workspace(db)
    components = db.scalars(
        select(Component)
        .where(
            Component.workspace_id == workspace.id,
            Component.is_archived.is_(False),
            Component.minimum_quantity > 0,
            Component.current_quantity < Component.minimum_quantity,
        )
        .options(selectinload(Component.supplier), selectinload(Component.location))
        .order_by(Component.name)
    ).all()
    items = []
    for component in components:
        current = Decimal(component.current_quantity)
        minimum = Decimal(component.minimum_quantity)
        items.append({
            "id": component.id,
            "inventory_code": component.inventory_code,
            "name": component.name,
            "current_quantity": str(current),
            "minimum_quantity": str(minimum),
            "reorder_quantity": str(max(minimum - current, Decimal("0"))),
            "unit": component.unit,
            "supplier_id": component.supplier_id,
            "supplier_name": component.supplier_name,
            "location_name": component.location.display_name if component.location else None,
        })
    return sorted(items, key=lambda item: (item["supplier_name"] or "", item["name"]))


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), _user: User = Depends(require_roles("owner", "editor", "viewer"))) -> dict:
    workspace = get_workspace(db)
    component_types = {
        item.name: item
        for item in db.scalars(
            select(ComponentType).where(
                ComponentType.workspace_id == workspace.id,
                ComponentType.is_active.is_(True),
            )
        )
    }
    components = list(db.scalars(select(Component).where(Component.workspace_id == workspace.id, Component.is_archived.is_(False))))
    total_quantity = sum((Decimal(item.current_quantity) for item in components), Decimal("0"))
    total_inventory_value = sum((Decimal(item.current_quantity) * Decimal(item.price or 0) for item in components), Decimal("0"))
    low_stock = [item for item in components if Decimal(item.minimum_quantity) > 0 and Decimal(item.current_quantity) > 0 and Decimal(item.current_quantity) <= Decimal(item.minimum_quantity)]
    out_of_stock = [item for item in components if Decimal(item.current_quantity) <= 0]
    active_component_types = db.scalar(select(func.count(ComponentType.id)).where(ComponentType.workspace_id == workspace.id, ComponentType.is_active.is_(True))) or 0
    recent_components = list(
        db.scalars(
            select(Component)
            .where(
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
            )
            .options(
                selectinload(Component.transaction_lines),
                selectinload(Component.project_lines),
            )
            .order_by(Component.created_at.desc(), Component.name)
            .limit(5)
        )
    )
    stock_by_type: dict[str, dict[str, Decimal | int | str]] = {}
    for item in components:
        quantity = Decimal(item.current_quantity)
        if quantity <= 0:
            continue
        type_name = item.package_type or "Other"
        component_type = component_types.get(type_name)
        summary = stock_by_type.setdefault(
            type_name,
            {
                "name": type_name,
                "product_count": 0,
                "stock_quantity": Decimal("0"),
                "icon_svg": component_type.icon_svg if component_type else None,
            },
        )
        summary["product_count"] = int(summary["product_count"]) + 1
        summary["stock_quantity"] = Decimal(summary["stock_quantity"]) + quantity
    return {
        "total_component_types": active_component_types,
        "total_products": len(components),
        "total_stock_quantity": str(total_quantity),
        "total_inventory_value": str(total_inventory_value),
        "low_stock_count": len(low_stock),
        "out_of_stock_count": len(out_of_stock),
        "recent_components": jsonable_encoder(
            [ComponentRead.model_validate(item) for item in recent_components]
        ),
        "component_type_stock": [
            {
                "name": str(summary["name"]),
                "product_count": int(summary["product_count"]),
                "stock_quantity": str(summary["stock_quantity"]),
                "icon_svg": summary["icon_svg"],
            }
            for summary in sorted(stock_by_type.values(), key=lambda value: str(value["name"]).lower())
        ],
    }


@router.get("/reports/inventory.csv")
def inventory_csv(
    request: Request,
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> Response:
    workspace = get_workspace(db)
    components = list(
        db.scalars(
            select(Component)
            .options(selectinload(Component.images), selectinload(Component.location))
            .where(
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
            )
            .order_by(Component.name)
        )
    )

    def external_image_url(path: str) -> str:
        forwarded_proto = request.headers.get("x-forwarded-proto")
        scheme = (
            forwarded_proto.split(",", 1)[0].strip()
            if forwarded_proto
            else request.url.scheme
        )
        forwarded_host = request.headers.get("x-forwarded-host")
        host = (
            forwarded_host.split(",", 1)[0].strip()
            if forwarded_host
            else request.headers.get("host", request.url.netloc)
        )
        return f"{scheme}://{host}{path}"

    content = build_inventory_csv(components, external_image_url)
    return Response(
        content="\ufeff" + content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=inventory.csv"},
    )


@router.get("/reports/inventory.pdf")
def inventory_pdf(
    db: Session = Depends(get_db),
    _user: User = Depends(require_roles("owner", "editor", "viewer")),
) -> Response:
    workspace = get_workspace(db)
    components = list(
        db.scalars(
            select(Component)
            .options(selectinload(Component.images), selectinload(Component.location))
            .where(
                Component.workspace_id == workspace.id,
                Component.is_archived.is_(False),
            )
            .order_by(Component.name)
        )
    )
    return Response(
        content=build_inventory_pdf(components),
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=inventory.pdf"},
    )


@router.post("/components/import/csv")
async def import_components_csv(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(require_roles("owner", "editor")),
) -> dict:
    workspace = get_workspace(db)
    raw_content = await file.read()
    try:
        text = raw_content.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw_content.decode("latin-1")

    reader = csv.reader(io.StringIO(text))
    rows = list(reader)
    if not rows:
        raise HTTPException(status_code=400, detail="CSV file is empty")

    header = [h.strip().lower() for h in rows[0]]
    field_map = {}
    for idx, col in enumerate(header):
        normalized = col.replace(" ", "_").replace("-", "_")
        field_map[normalized] = idx

    def get_val(row: list[str], *aliases: str) -> str:
        for alias in aliases:
            norm = alias.lower().replace(" ", "_").replace("-", "_")
            if norm in field_map and field_map[norm] < len(row):
                val = row[field_map[norm]].strip()
                if val:
                    return val
        return ""

    # Preload categories, types, locations, and suppliers for matching
    default_cat = db.scalars(select(Category).where(Category.workspace_id == workspace.id)).first()
    if not default_cat:
        raise HTTPException(status_code=400, detail="No category found in workspace")

    existing_types = {t.name.strip().lower(): t for t in db.scalars(select(ComponentType).where(ComponentType.workspace_id == workspace.id)).all()}
    existing_locations = {l.display_name.strip().lower(): l for l in db.scalars(select(Location).where(Location.workspace_id == workspace.id, Location.is_active == True)).all()}
    for loc in list(existing_locations.values()):
        if loc.name:
            existing_locations[loc.name.strip().lower()] = loc
    existing_suppliers = {s.name.strip().lower(): s for s in db.scalars(select(Supplier).where(Supplier.workspace_id == workspace.id, Supplier.is_active == True)).all()}

    imported_count = 0
    skipped_count = 0
    errors: list[str] = []

    for row_idx, row in enumerate(rows[1:], start=2):
        if not row or not any(field.strip() for field in row):
            continue

        name = get_val(row, "name", "component_name", "title")
        if not name:
            skipped_count += 1
            errors.append(f"Row {row_idx}: Component name is missing")
            continue

        package_type_name = get_val(row, "type", "package_type", "component_type")
        if package_type_name and package_type_name.strip().lower() not in existing_types:
            new_type = ComponentType(
                workspace_id=workspace.id,
                name=package_type_name.strip(),
                is_active=True,
            )
            db.add(new_type)
            db.flush()
            existing_types[package_type_name.strip().lower()] = new_type

        location_name = get_val(row, "location", "location_name")
        location_id = None
        if location_name:
            loc_lower = location_name.strip().lower()
            if loc_lower in existing_locations:
                location_id = existing_locations[loc_lower].id
            else:
                new_loc = Location(
                    workspace_id=workspace.id,
                    name=location_name.strip(),
                    display_name=location_name.strip(),
                    is_active=True,
                )
                db.add(new_loc)
                db.flush()
                existing_locations[loc_lower] = new_loc
                location_id = new_loc.id

        supplier_name = get_val(row, "supplier", "supplier_name")
        supplier_id = None
        if supplier_name:
            supp_lower = supplier_name.strip().lower()
            if supp_lower in existing_suppliers:
                supplier_id = existing_suppliers[supp_lower].id
            else:
                new_supp = Supplier(
                    workspace_id=workspace.id,
                    name=supplier_name.strip(),
                    is_active=True,
                )
                db.add(new_supp)
                db.flush()
                existing_suppliers[supp_lower] = new_supp
                supplier_id = new_supp.id

        qty_str = get_val(row, "quantity", "current_quantity", "opening_quantity", "stock")
        try:
            opening_quantity = Decimal(qty_str) if qty_str else Decimal("0")
        except Exception:
            opening_quantity = Decimal("0")

        min_str = get_val(row, "minimum", "minimum_quantity", "min_quantity", "min")
        try:
            minimum_quantity = Decimal(min_str) if min_str else Decimal("0")
        except Exception:
            minimum_quantity = Decimal("0")

        price_str = get_val(row, "price", "unit_price", "cost")
        price = None
        if price_str:
            try:
                price = Decimal(re.sub(r"[^\d.]", "", price_str))
            except Exception:
                price = None

        unit = get_val(row, "unit") or "Pieces"
        description = get_val(row, "details", "description", "desc")
        part_number = get_val(row, "part_number", "part_no", "part#", "mpn")
        manufacturer = get_val(row, "manufacturer", "mfg", "brand")
        model_number = get_val(row, "model_number", "model")
        datasheet_url = get_val(row, "datasheet", "datasheet_url", "pdf")
        expiry_date = get_val(row, "expiry_date", "expiry", "expiration_date")

        try:
            create_component(
                db,
                ComponentCreate(
                    name=name,
                    category_id=default_cat.id,
                    package_type=package_type_name or None,
                    description=description or None,
                    manufacturer=manufacturer or None,
                    model_number=model_number or None,
                    part_number=part_number or None,
                    unit=unit,
                    opening_quantity=opening_quantity,
                    minimum_quantity=minimum_quantity,
                    price=price,
                    location_id=location_id,
                    supplier_id=supplier_id,
                    datasheet_url=datasheet_url or None,
                    expiry_date=expiry_date or None,
                ),
                user.id,
            )
            imported_count += 1
        except HTTPException as e:
            skipped_count += 1
            errors.append(f"Row {row_idx} ('{name}'): {e.detail}")
        except Exception as e:
            skipped_count += 1
            errors.append(f"Row {row_idx} ('{name}'): {str(e)}")

    return {
        "success": True,
        "imported": imported_count,
        "skipped": skipped_count,
        "errors": errors[:20],
    }
