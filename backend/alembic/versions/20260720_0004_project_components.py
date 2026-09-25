"""add project components

Revision ID: 20260720_0004
Revises: 20260714_0003
Create Date: 2026-07-20 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260720_0004"
down_revision = "20260714_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "project_components",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("project_id", sa.String(length=36), nullable=False),
        sa.Column("component_id", sa.String(length=36), nullable=False),
        sa.Column("quantity", sa.Numeric(precision=18, scale=4), nullable=False),
        sa.Column("unit", sa.String(length=32), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_by", sa.String(length=36), nullable=True),
        sa.Column("updated_by", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["component_id"], ["components.id"]),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"]),
        sa.ForeignKeyConstraint(["project_id"], ["projects.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["updated_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("project_id", "component_id", name="uq_project_component"),
    )
    op.create_index(
        op.f("ix_project_components_component_id"),
        "project_components",
        ["component_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_project_components_project_id"),
        "project_components",
        ["project_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_project_components_project_id"),
        table_name="project_components",
    )
    op.drop_index(
        op.f("ix_project_components_component_id"),
        table_name="project_components",
    )
    op.drop_table("project_components")
