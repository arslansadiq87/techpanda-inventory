"""component types

Revision ID: 20260712_0002
Revises: 20260711_0001
Create Date: 2026-07-12 01:40:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260712_0002"
down_revision = "20260711_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "component_types",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("workspace_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("normalized_name", sa.String(length=80), nullable=False),
        sa.Column("display_order", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("workspace_id", "normalized_name", name="uq_component_type_workspace_name"),
    )
    op.create_index(op.f("ix_component_types_workspace_id"), "component_types", ["workspace_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_component_types_workspace_id"), table_name="component_types")
    op.drop_table("component_types")
