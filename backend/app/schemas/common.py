from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class OrmModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    code_prefix: str = Field(min_length=1, max_length=12)
    description: str | None = None


class CategoryRead(OrmModel):
    id: str
    name: str
    code_prefix: str
    description: str | None = None
    is_active: bool


class ComponentTypeCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    icon_svg: str | None = Field(default=None, max_length=100_000)
    parent_type_id: str | None = None


class ComponentTypeUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    icon_svg: str | None = Field(default=None, max_length=100_000)
    parent_type_id: str | None = None
    is_active: bool | None = None


class ComponentTypeRead(OrmModel):
    id: str
    name: str
    icon_svg: str | None = None
    parent_type_id: str | None = None
    parent_type_name: str | None = None
    is_active: bool


class LocationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    cabinet: str | None = Field(default=None, max_length=80)
    shelf: str | None = Field(default=None, max_length=80)
    drawer: str | None = Field(default=None, max_length=80)
    box: str | None = Field(default=None, max_length=80)
    bin: str | None = Field(default=None, max_length=80)
    description: str | None = None
    generate_qr_code: bool = False
    qr_code_value: str | None = None


class LocationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    cabinet: str | None = Field(default=None, max_length=80)
    shelf: str | None = Field(default=None, max_length=80)
    drawer: str | None = Field(default=None, max_length=80)
    box: str | None = Field(default=None, max_length=80)
    bin: str | None = Field(default=None, max_length=80)
    description: str | None = None
    generate_qr_code: bool | None = None
    qr_code_value: str | None = None
    is_active: bool | None = None


class LocationRead(OrmModel):
    id: str
    name: str
    cabinet: str | None = None
    shelf: str | None = None
    drawer: str | None = None
    box: str | None = None
    bin: str | None = None
    description: str | None = None
    display_name: str
    qr_code_value: str | None = None
    is_active: bool


class SupplierCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    website: str | None = Field(default=None, max_length=500)
    contact: str | None = Field(default=None, max_length=255)
    notes: str | None = None


class SupplierUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    website: str | None = Field(default=None, max_length=500)
    contact: str | None = Field(default=None, max_length=255)
    notes: str | None = None
    is_active: bool | None = None


class SupplierRead(OrmModel):
    id: str
    name: str
    website: str | None = None
    contact: str | None = None
    notes: str | None = None
    is_favorite: bool
    is_active: bool
    created_at: datetime


class ComponentCreate(BaseModel):
    name: str = Field(min_length=1, max_length=220)
    category_id: str
    manufacturer: str | None = None
    model_number: str | None = None
    part_number: str | None = None
    package_type: str | None = None
    description: str | None = None
    opening_quantity: Decimal = Decimal("0")
    minimum_quantity: Decimal = Decimal("0")
    unit: str = "Pieces"
    location_id: str | None = None
    location_name: str | None = None
    supplier_id: str | None = None
    purchase_url: str | None = None
    datasheet_url: str | None = None
    notes: str | None = None
    tags: list[str] = []
    specifications: dict[str, str] = {}
    barcode: str | None = None
    price: Decimal | None = None
    datasheet_text: str | None = None
    expiry_date: str | None = None


class ComponentUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=220)
    manufacturer: str | None = Field(default=None, max_length=160)
    package_type: str | None = Field(default=None, max_length=80)
    description: str | None = None
    unit: str | None = Field(default=None, min_length=1, max_length=32)
    location_id: str | None = None
    supplier_id: str | None = None
    price: Decimal | None = None
    datasheet_url: str | None = None
    datasheet_text: str | None = None
    expiry_date: str | None = None


class ComponentRead(OrmModel):
    id: str
    inventory_code: str
    name: str
    category_id: str
    manufacturer: str | None = None
    model_number: str | None = None
    part_number: str | None = None
    package_type: str | None = None
    description: str | None = None
    current_quantity: Decimal
    minimum_quantity: Decimal
    unit: str
    location_id: str | None = None
    location_name: str | None = None
    supplier_id: str | None = None
    supplier_name: str | None = None
    price: Decimal | None = None
    datasheet_url: str | None = None
    datasheet_text: str | None = None
    expiry_date: str | None = None
    primary_image_thumbnail: str | None = None
    primary_image_preview: str | None = None
    can_delete: bool
    is_favorite: bool
    is_archived: bool
    created_at: datetime
    updated_at: datetime


class TransactionLineCreate(BaseModel):
    component_id: str
    quantity: Decimal = Field(gt=0)
    unit_cost_minor: int | None = None
    notes: str | None = None


class TransactionCreate(BaseModel):
    transaction_type: str = Field(pattern="^(stock_in|stock_out|return|adjustment|damage|loss)$")
    idempotency_key: str = Field(min_length=8, max_length=120)
    project_id: str | None = None
    supplier_id: str | None = None
    reason: str | None = None
    notes: str | None = None
    lines: list[TransactionLineCreate] = Field(min_length=1)


class TransactionRead(OrmModel):
    id: str
    transaction_code: str
    transaction_type: str
    status: str
    project_id: str | None = None
    can_modify: bool
    line_count: int
    total_quantity: Decimal
    created_at: datetime


class TransactionUpdate(BaseModel):
    transaction_type: str = Field(
        pattern="^(stock_in|stock_out|return|adjustment|damage|loss)$"
    )
    reason: str | None = None
    notes: str | None = None
    lines: list[TransactionLineCreate] = Field(min_length=1)


class TransactionLineRead(OrmModel):
    component_id: str
    quantity: Decimal
    unit: str
    line_notes: str | None = None
    component_name: str
    inventory_code: str
    package_type: str | None = None
    manufacturer: str | None = None
    location_name: str | None = None
    available_quantity: Decimal
    primary_image_thumbnail: str | None = None


class TransactionDetailRead(TransactionRead):
    reason: str | None = None
    notes: str | None = None
    lines: list[TransactionLineRead]


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=220)
    project_type: str = "Personal Project"
    status: str = "Planned"
    status: str = "To Do"
    youtube_video_title: str | None = None
    youtube_video_url: str | None = None
    description: str | None = Field(default=None, max_length=20_000)
    notes: str | None = None


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=220)
    status: str | None = None
    project_type: str | None = None
    description: str | None = Field(default=None, max_length=20_000)


class ProjectRead(OrmModel):
    id: str
    name: str
    project_type: str
    status: str
    youtube_video_title: str | None = None
    youtube_video_url: str | None = None
    description: str | None = None
    image_url: str | None = None
    is_archived: bool
    total_cost: Decimal | None = None
    created_at: datetime


class ProjectComponentUpdate(BaseModel):
    quantity: Decimal = Field(gt=0)
    notes: str | None = Field(default=None, max_length=2000)


class ProjectComponentBatchLine(BaseModel):
    component_id: str
    quantity: Decimal = Field(gt=0)
    notes: str | None = Field(default=None, max_length=2000)


class ProjectComponentBatchUpdate(BaseModel):
    lines: list[ProjectComponentBatchLine]


class ProjectKitLineCreate(BaseModel):
    component_id: str
    quantity: Decimal = Field(gt=0)
    unit: str = Field(default="Pieces", min_length=1, max_length=32)
    notes: str | None = Field(default=None, max_length=2000)


class ProjectKitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=220)
    description: str | None = None
    is_favorite: bool = False
    lines: list[ProjectKitLineCreate] = []


class ProjectKitUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=220)
    description: str | None = None
    is_favorite: bool | None = None
    lines: list[ProjectKitLineCreate] | None = None


class ProjectKitLineRead(OrmModel):
    id: str
    project_kit_id: str
    component_id: str
    quantity: Decimal
    unit: str
    notes: str | None = None
    inventory_code: str
    component_name: str


class ProjectKitRead(OrmModel):
    id: str
    workspace_id: str
    name: str
    description: str | None = None
    is_favorite: bool
    created_at: datetime
    updated_at: datetime
    lines: list[ProjectKitLineRead] = []


class ProjectComponentRead(OrmModel):
    id: str
    project_id: str
    component_id: str
    quantity: Decimal
    unit: str
    notes: str | None = None
    inventory_code: str
    component_name: str
    package_type: str | None = None
    manufacturer: str | None = None
    location_name: str | None = None
    price: Decimal | None = None
    total_cost: Decimal | None = None
    available_quantity: Decimal
    primary_image_thumbnail: str | None = None
    created_at: datetime
    updated_at: datetime
