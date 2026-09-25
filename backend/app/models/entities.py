from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


def uuid_str() -> str:
    return str(uuid.uuid4())


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Role(str, enum.Enum):
    owner = "owner"
    editor = "editor"
    viewer = "viewer"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    normalized_email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[str] = mapped_column(String(32), default=Role.owner.value, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failed_login_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    device_name: Mapped[str | None] = mapped_column(String(120))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped[User] = relationship()


class Workspace(Base):
    __tablename__ = "workspaces"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    name: Mapped[str] = mapped_column(String(160), nullable=False, default="Tech Panda")
    default_currency: Mapped[str] = mapped_column(String(8), default="CNY", nullable=False)
    default_unit: Mapped[str] = mapped_column(String(32), default="Pieces", nullable=False)
    allow_negative_stock: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), default="Asia/Karachi", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class Category(Base):
    __tablename__ = "categories"
    __table_args__ = (UniqueConstraint("workspace_id", "normalized_name", name="uq_category_workspace_name"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(160), nullable=False)
    code_prefix: Mapped[str] = mapped_column(String(12), nullable=False)
    parent_category_id: Mapped[str | None] = mapped_column(ForeignKey("categories.id"))
    description: Mapped[str | None] = mapped_column(Text)
    icon_name: Mapped[str | None] = mapped_column(String(64))
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class SpecificationDefinition(Base):
    __tablename__ = "specification_definitions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id", ondelete="CASCADE"), nullable=False, index=True)
    field_key: Mapped[str] = mapped_column(String(80), nullable=False)
    display_label: Mapped[str] = mapped_column(String(160), nullable=False)
    data_type: Mapped[str] = mapped_column(String(32), default="text", nullable=False)
    unit: Mapped[str | None] = mapped_column(String(32))
    is_required: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_searchable: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    default_value: Mapped[str | None] = mapped_column(Text)
    options_json: Mapped[str | None] = mapped_column(Text)
    help_text: Mapped[str | None] = mapped_column(Text)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class ComponentType(Base):
    __tablename__ = "component_types"
    __table_args__ = (UniqueConstraint("workspace_id", "normalized_name", name="uq_component_type_workspace_name"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    normalized_name: Mapped[str] = mapped_column(String(80), nullable=False)
    parent_type_id: Mapped[str | None] = mapped_column(ForeignKey("component_types.id", ondelete="SET NULL"), nullable=True)
    icon_svg: Mapped[str | None] = mapped_column(Text)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    parent_type: Mapped["ComponentType | None"] = relationship("ComponentType", remote_side=[id], lazy="selectin")

    @property
    def parent_type_name(self) -> str | None:
        return self.parent_type.name if self.parent_type else None


class Location(Base):
    __tablename__ = "locations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    parent_location_id: Mapped[str | None] = mapped_column(ForeignKey("locations.id"))
    cabinet: Mapped[str | None] = mapped_column(String(80))
    shelf: Mapped[str | None] = mapped_column(String(80))
    drawer: Mapped[str | None] = mapped_column(String(80))
    box: Mapped[str | None] = mapped_column(String(80))
    bin: Mapped[str | None] = mapped_column(String(80))
    description: Mapped[str | None] = mapped_column(Text)
    qr_code_value: Mapped[str | None] = mapped_column(String(160), unique=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    @property
    def display_name(self) -> str:
        parts = [self.name, self.cabinet, self.shelf, self.drawer, self.box, self.bin]
        return " / ".join(part for part in parts if part)


class Supplier(Base):
    __tablename__ = "suppliers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    website: Mapped[str | None] = mapped_column(String(500))
    contact: Mapped[str | None] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class Component(Base):
    __tablename__ = "components"
    __table_args__ = (UniqueConstraint("workspace_id", "inventory_code", name="uq_component_workspace_code"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    inventory_code: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(220), nullable=False, index=True)
    normalized_name: Mapped[str] = mapped_column(String(220), nullable=False, index=True)
    category_id: Mapped[str] = mapped_column(ForeignKey("categories.id"), nullable=False, index=True)
    subcategory_id: Mapped[str | None] = mapped_column(ForeignKey("categories.id"))
    manufacturer: Mapped[str | None] = mapped_column(String(160))
    model_number: Mapped[str | None] = mapped_column(String(160))
    part_number: Mapped[str | None] = mapped_column(String(160), index=True)
    package_type: Mapped[str | None] = mapped_column(String(80))
    description: Mapped[str | None] = mapped_column(Text)
    current_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), default=0, nullable=False)
    minimum_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), default=0, nullable=False)
    unit: Mapped[str] = mapped_column(String(32), default="Pieces", nullable=False)
    quantity_precision: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    location_id: Mapped[str | None] = mapped_column(ForeignKey("locations.id"))
    drawer: Mapped[str | None] = mapped_column(String(80))
    box: Mapped[str | None] = mapped_column(String(80))
    supplier_id: Mapped[str | None] = mapped_column(ForeignKey("suppliers.id"))
    purchase_source: Mapped[str | None] = mapped_column(String(255))
    purchase_url: Mapped[str | None] = mapped_column(String(500))
    unit_cost_minor: Mapped[int | None] = mapped_column(Integer)
    price: Mapped[Decimal | None] = mapped_column(Numeric(18, 4), nullable=True)
    currency: Mapped[str] = mapped_column(String(8), default="CNY", nullable=False)
    purchase_date: Mapped[str | None] = mapped_column(String(20))
    datasheet_url: Mapped[str | None] = mapped_column(String(500))
    datasheet_text: Mapped[str | None] = mapped_column(Text)
    expiry_date: Mapped[str | None] = mapped_column(String(20))
    notes: Mapped[str | None] = mapped_column(Text)
    tags_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    specification_values_json: Mapped[str] = mapped_column(Text, default="{}", nullable=False)
    barcode: Mapped[str | None] = mapped_column(String(160), index=True)
    qr_code_value: Mapped[str | None] = mapped_column(String(160), unique=True)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    search_text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    updated_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    category: Mapped[Category] = relationship(foreign_keys=[category_id])
    location: Mapped[Location | None] = relationship(foreign_keys=[location_id])
    supplier: Mapped[Supplier | None] = relationship(foreign_keys=[supplier_id])
    images: Mapped[list["ComponentImage"]] = relationship("ComponentImage", order_by="ComponentImage.created_at.desc()", cascade="all, delete-orphan")
    transaction_lines: Mapped[list["InventoryTransactionLine"]] = relationship(
        "InventoryTransactionLine",
        viewonly=True,
    )
    project_lines: Mapped[list["ProjectComponent"]] = relationship(
        "ProjectComponent",
        viewonly=True,
    )

    @property
    def primary_image_thumbnail(self) -> str | None:
        image = next((item for item in self.images if item.is_primary), self.images[0] if self.images else None)
        if not image:
            return None
        return f"/api/v1/media/thumbnails/{image.stored_filename}"

    @property
    def primary_image_preview(self) -> str | None:
        image = next((item for item in self.images if item.is_primary), self.images[0] if self.images else None)
        if not image:
            return None
        return f"/api/v1/media/previews/{image.stored_filename}"

    @property
    def location_name(self) -> str | None:
        return self.location.display_name if self.location else None

    @property
    def supplier_name(self) -> str | None:
        return self.supplier.name if self.supplier else None

    @property
    def can_delete(self) -> bool:
        return not self.transaction_lines and not self.project_lines


class ComponentImage(Base):
    __tablename__ = "component_images"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    component_id: Mapped[str] = mapped_column(ForeignKey("components.id", ondelete="CASCADE"), nullable=False, index=True)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(120), nullable=False)
    file_size: Mapped[int] = mapped_column(Integer, nullable=False)
    width: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[int | None] = mapped_column(Integer)
    original_path: Mapped[str] = mapped_column(String(500), nullable=False)
    preview_path: Mapped[str] = mapped_column(String(500), nullable=False)
    thumbnail_path: Mapped[str] = mapped_column(String(500), nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    created_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(220), nullable=False)
    project_type: Mapped[str] = mapped_column(String(80), default="Personal Project", nullable=False)
    status: Mapped[str] = mapped_column(String(80), default="Planned", nullable=False)
    status: Mapped[str] = mapped_column(String(80), default="To Do", nullable=False)
    start_date: Mapped[str | None] = mapped_column(String(20))
    completion_date: Mapped[str | None] = mapped_column(String(20))
    youtube_video_title: Mapped[str | None] = mapped_column(String(255))
    youtube_video_url: Mapped[str | None] = mapped_column(String(500))
    description: Mapped[str | None] = mapped_column(Text)
    notes: Mapped[str | None] = mapped_column(Text)
    image_path: Mapped[str | None] = mapped_column(String(500))
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    components: Mapped[list["ProjectComponent"]] = relationship(
        back_populates="project",
        cascade="all, delete-orphan",
    )

    @property
    def total_cost(self) -> Decimal:
        cost = Decimal("0")
        for line in self.components:
            if line.component and line.component.price is not None:
                cost += Decimal(str(line.quantity)) * Decimal(str(line.component.price))
        return cost.quantize(Decimal("0.0001"))

    @property
    def image_url(self) -> str | None:
        if not self.image_path:
            return None
        return f"/api/v1/media/projects/{Path(self.image_path).name}"


class ProjectComponent(Base):
    __tablename__ = "project_components"
    __table_args__ = (
        UniqueConstraint("project_id", "component_id", name="uq_project_component"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    project_id: Mapped[str] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    component_id: Mapped[str] = mapped_column(
        ForeignKey("components.id"),
        nullable=False,
        index=True,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    unit: Mapped[str] = mapped_column(String(32), default="Pieces", nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    created_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    updated_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    project: Mapped[Project] = relationship(back_populates="components")
    component: Mapped[Component] = relationship()

    @property
    def inventory_code(self) -> str:
        return self.component.inventory_code

    @property
    def component_name(self) -> str:
        return self.component.name

    @property
    def package_type(self) -> str | None:
        return self.component.package_type

    @property
    def manufacturer(self) -> str | None:
        return self.component.manufacturer

    @property
    def location_name(self) -> str | None:
        return self.component.location_name

    @property
    def price(self) -> Decimal | None:
        return self.component.price if self.component else None

    @property
    def total_cost(self) -> Decimal | None:
        if self.component and self.component.price is not None:
            return (Decimal(str(self.quantity)) * Decimal(str(self.component.price))).quantize(Decimal("0.0001"))
        return None

    @property
    def available_quantity(self) -> Decimal:
        return self.component.current_quantity

    @property
    def primary_image_thumbnail(self) -> str | None:
        return self.component.primary_image_thumbnail


class ProjectKit(Base):
    __tablename__ = "project_kits"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(220), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)


class ProjectKitLine(Base):
    __tablename__ = "project_kit_lines"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    project_kit_id: Mapped[str] = mapped_column(ForeignKey("project_kits.id", ondelete="CASCADE"), nullable=False)
    component_id: Mapped[str] = mapped_column(ForeignKey("components.id"), nullable=False)
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    unit: Mapped[str] = mapped_column(String(32), default="Pieces", nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)


class InventoryTransaction(Base):
    __tablename__ = "inventory_transactions"
    __table_args__ = (UniqueConstraint("workspace_id", "idempotency_key", name="uq_transaction_idempotency"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    workspace_id: Mapped[str] = mapped_column(ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False, index=True)
    transaction_code: Mapped[str] = mapped_column(String(40), nullable=False, unique=True)
    transaction_type: Mapped[str] = mapped_column(String(40), nullable=False)
    status: Mapped[str] = mapped_column(String(40), default="posted", nullable=False)
    project_id: Mapped[str | None] = mapped_column(ForeignKey("projects.id"))
    supplier_id: Mapped[str | None] = mapped_column(ForeignKey("suppliers.id"))
    reference_number: Mapped[str | None] = mapped_column(String(120))
    reason: Mapped[str | None] = mapped_column(String(160))
    notes: Mapped[str | None] = mapped_column(Text)
    line_count: Mapped[int] = mapped_column(Integer, nullable=False)
    total_quantity: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    total_cost_minor: Mapped[int | None] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(8), default="CNY", nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(120), nullable=False)
    reverses_transaction_id: Mapped[str | None] = mapped_column(ForeignKey("inventory_transactions.id"))
    created_by: Mapped[str | None] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    lines: Mapped[list[InventoryTransactionLine]] = relationship(back_populates="transaction", cascade="all, delete-orphan")

    @property
    def can_modify(self) -> bool:
        return self.project_id is None


class InventoryTransactionLine(Base):
    __tablename__ = "inventory_transaction_lines"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uuid_str)
    transaction_id: Mapped[str] = mapped_column(ForeignKey("inventory_transactions.id", ondelete="CASCADE"), nullable=False)
    component_id: Mapped[str] = mapped_column(ForeignKey("components.id"), nullable=False)
    quantity_delta: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    quantity_before: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    quantity_after: Mapped[Decimal] = mapped_column(Numeric(18, 4), nullable=False)
    unit: Mapped[str] = mapped_column(String(32), default="Pieces", nullable=False)
    unit_cost_minor: Mapped[int | None] = mapped_column(Integer)
    line_notes: Mapped[str | None] = mapped_column(Text)

    transaction: Mapped[InventoryTransaction] = relationship(back_populates="lines")
    component: Mapped[Component] = relationship()

    @property
    def quantity(self) -> Decimal:
        return abs(Decimal(self.quantity_delta))

    @property
    def component_name(self) -> str:
        return self.component.name

    @property
    def inventory_code(self) -> str:
        return self.component.inventory_code

    @property
    def package_type(self) -> str | None:
        return self.component.package_type

    @property
    def manufacturer(self) -> str | None:
        return self.component.manufacturer

    @property
    def location_name(self) -> str | None:
        return self.component.location_name

    @property
    def available_quantity(self) -> Decimal:
        return self.component.current_quantity

    @property
    def primary_image_thumbnail(self) -> str | None:
        return self.component.primary_image_thumbnail
