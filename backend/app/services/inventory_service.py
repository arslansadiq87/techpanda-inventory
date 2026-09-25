import json
from decimal import Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models import Category, Component, InventoryTransaction, InventoryTransactionLine, Workspace
from app.schemas.common import ComponentCreate, TransactionCreate


def normalize_text(value: str | None) -> str:
    return (value or "").strip().lower()


def clean_optional_text(value: str | None) -> str | None:
    cleaned = (value or "").strip()
    return cleaned or None


def get_workspace(db: Session) -> Workspace:
    workspace = db.scalars(select(Workspace).limit(1)).first()
    if not workspace:
        raise HTTPException(status_code=500, detail="Workspace is not initialized")
    return workspace


def find_component_for_stock(db: Session, workspace_id: str, search: str) -> Component | None:
    """Shared authenticated stock lookup used by the web API and voice client."""
    term = search.strip()
    if not term:
        return None
    exact = select(Component).where(
        Component.workspace_id == workspace_id,
        Component.is_archived.is_(False),
        or_(
            Component.inventory_code.ilike(term),
            Component.part_number.ilike(term),
            Component.name.ilike(term),
        ),
    )
    component = db.scalar(exact)
    if component:
        return component
    pattern = f"%{term}%"
    component = db.scalar(select(Component).where(
        Component.workspace_id == workspace_id,
        Component.is_archived.is_(False),
        or_(
            Component.name.ilike(pattern),
            Component.part_number.ilike(pattern),
            Component.normalized_name.ilike(pattern),
            Component.search_text.ilike(pattern),
        ),
    ))
    if component:
        return component

    words = [word for word in normalize_text(term).replace("ohms", "ohm").split() if len(word) > 1]
    if words and words[0].isdigit():
        words = words[1:]
    if any(word in {"resistance", "resistor", "resistors"} for word in words):
        words.append("resistor")
    words = list(dict.fromkeys(words))
    if words:
        return db.scalar(select(Component).where(
            Component.workspace_id == workspace_id,
            Component.is_archived.is_(False),
            *(Component.search_text.ilike(f"%{word}%") for word in words),
        ).order_by(Component.name))
    return None


def component_code_prefix(package_type: str | None, category: Category) -> str:
    cleaned = "".join(char for char in (package_type or "") if char.isalnum())
    return (cleaned[:3] or category.code_prefix).upper()


def next_component_code(db: Session, workspace_id: str, prefix: str) -> str:
    like = f"{prefix}-%"
    count = db.scalar(select(func.count(Component.id)).where(Component.workspace_id == workspace_id, Component.inventory_code.like(like))) or 0
    while True:
        code = f"{prefix}-{count + 1:06d}"
        exists = db.scalar(select(Component.id).where(Component.workspace_id == workspace_id, Component.inventory_code == code))
        if not exists:
            return code
        count += 1


def build_search_text(payload: ComponentCreate, code: str) -> str:
    parts = [
        code,
        payload.name,
        payload.manufacturer,
        payload.model_number,
        payload.part_number,
        payload.package_type,
        payload.description,
        payload.barcode,
        " ".join(payload.tags),
        " ".join(f"{k} {v}" for k, v in payload.specifications.items()),
        payload.datasheet_text,
        payload.expiry_date,
    ]
    return normalize_text(" ".join(item for item in parts if item))


def build_component_search_text(component: Component) -> str:
    parts = [
        component.inventory_code,
        component.name,
        component.manufacturer,
        component.model_number,
        component.part_number,
        component.package_type,
        component.description,
        component.location_name,
        component.barcode,
        component.tags_json,
        component.specification_values_json,
        component.datasheet_text,
        component.expiry_date,
    ]
    return normalize_text(" ".join(item for item in parts if item))


def create_component(db: Session, payload: ComponentCreate, user_id: str) -> Component:
    workspace = get_workspace(db)
    category = db.get(Category, payload.category_id)
    if not category or category.workspace_id != workspace.id:
        raise HTTPException(status_code=404, detail="Category not found")
    name = payload.name.strip()
    package_type = clean_optional_text(payload.package_type)
    manufacturer = clean_optional_text(payload.manufacturer)
    description = clean_optional_text(payload.description)
    location_id = None
    if payload.location_id:
        from app.models import Location

        location = db.get(Location, payload.location_id)
        if not location or location.workspace_id != workspace.id or not location.is_active:
            raise HTTPException(status_code=404, detail="Location not found")
        location_id = location.id

    supplier_id = None
    if payload.supplier_id:
        from app.models import Supplier

        supplier = db.get(Supplier, payload.supplier_id)
        if not supplier or supplier.workspace_id != workspace.id or not supplier.is_active:
            raise HTTPException(status_code=404, detail="Supplier not found")
        supplier_id = supplier.id

    duplicate = db.scalars(
        select(Component).where(
            Component.workspace_id == workspace.id,
            Component.is_archived.is_(False),
            Component.normalized_name == normalize_text(name),
            Component.package_type == package_type,
            Component.manufacturer == manufacturer,
            Component.location_id == location_id,
        )
    ).first()
    if duplicate:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Component already exists as {duplicate.inventory_code}")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Component '{name}' already exists as {duplicate.inventory_code}")

    code = next_component_code(db, workspace.id, component_code_prefix(package_type, category))
    component = Component(
        workspace_id=workspace.id,
        inventory_code=code,
        name=name,
        normalized_name=normalize_text(name),
        category_id=category.id,
        manufacturer=manufacturer,
        model_number=payload.model_number,
        part_number=payload.part_number,
        package_type=package_type,
        description=description,
        current_quantity=Decimal("0"),
        minimum_quantity=payload.minimum_quantity,
        unit=payload.unit,
        price=payload.price,
        unit_cost_minor=int(round(payload.price * 100)) if payload.price is not None else None,
        location_id=location_id,
        supplier_id=supplier_id,
        purchase_url=payload.purchase_url,
        datasheet_url=payload.datasheet_url,
        datasheet_text=payload.datasheet_text,
        expiry_date=payload.expiry_date,
        notes=payload.notes,
        tags_json=json.dumps(payload.tags),
        specification_values_json=json.dumps(payload.specifications),
        barcode=payload.barcode,
        qr_code_value=f"component:{code}",
        search_text=build_search_text(payload, code),
        created_by=user_id,
        updated_by=user_id,
    )
    db.add(component)
    db.flush()
    if payload.opening_quantity > 0:
        create_transaction(
            db,
            TransactionCreate(
                transaction_type="stock_in",
                idempotency_key=f"opening-{component.id}",
                reason="Opening stock",
                lines=[{"component_id": component.id, "quantity": payload.opening_quantity}],
            ),
            user_id,
        )
    db.commit()
    db.refresh(component)
    return component


def create_transaction(db: Session, payload: TransactionCreate, user_id: str) -> InventoryTransaction:
    workspace = get_workspace(db)
    # Serialize transaction-number and idempotency allocation per workspace.
    # Counting rows is unsafe after deletions and without this lock concurrent
    # API workers can choose the same transaction code.
    db.scalar(
        select(Workspace.id)
        .where(Workspace.id == workspace.id)
        .with_for_update()
    )
    existing = db.scalars(
        select(InventoryTransaction).where(
            InventoryTransaction.workspace_id == workspace.id,
            InventoryTransaction.idempotency_key == payload.idempotency_key,
        )
    ).first()
    if existing:
        return existing

    multiplier = Decimal("1") if payload.transaction_type in {"stock_in", "return"} else Decimal("-1")
    if payload.transaction_type == "adjustment":
        multiplier = Decimal("1")

    highest_code = db.scalar(
        select(func.max(InventoryTransaction.transaction_code)).where(
            InventoryTransaction.workspace_id == workspace.id,
            InventoryTransaction.transaction_code.like("TX-%"),
        )
    )
    try:
        next_transaction_number = int((highest_code or "TX-00000000").split("-")[-1]) + 1
    except ValueError:
        next_transaction_number = (
            db.scalar(
                select(func.count(InventoryTransaction.id)).where(
                    InventoryTransaction.workspace_id == workspace.id
                )
            )
            or 0
        ) + 1
    transaction_code = f"TX-{next_transaction_number:08d}"
    while db.scalar(
        select(InventoryTransaction.id).where(
            InventoryTransaction.transaction_code == transaction_code
        )
    ):
        next_transaction_number += 1
        transaction_code = f"TX-{next_transaction_number:08d}"

    transaction = InventoryTransaction(
        workspace_id=workspace.id,
        transaction_code=transaction_code,
        transaction_type=payload.transaction_type,
        project_id=payload.project_id,
        supplier_id=payload.supplier_id,
        reason=payload.reason,
        notes=payload.notes,
        line_count=len(payload.lines),
        total_quantity=sum((line.quantity for line in payload.lines), Decimal("0")),
        idempotency_key=payload.idempotency_key,
        created_by=user_id,
    )
    db.add(transaction)
    db.flush()

    for line in payload.lines:
        component = db.get(Component, line.component_id)
        if not component or component.workspace_id != workspace.id or component.is_archived:
            raise HTTPException(status_code=404, detail="Component not found")
        before = Decimal(component.current_quantity)
        delta = line.quantity * multiplier
        after = before + delta
        if after < 0 and not workspace.allow_negative_stock:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Insufficient stock for {component.inventory_code}")
        component.current_quantity = after
        db.add(
            InventoryTransactionLine(
                transaction_id=transaction.id,
                component_id=component.id,
                quantity_delta=delta,
                quantity_before=before,
                quantity_after=after,
                unit=component.unit,
                unit_cost_minor=line.unit_cost_minor,
                line_notes=line.notes,
            )
        )
    return transaction
