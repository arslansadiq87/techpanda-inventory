"""add SVG icons to component types

Revision ID: 20260714_0003
Revises: 20260712_0002
Create Date: 2026-07-14 08:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260714_0003"
down_revision = "20260712_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("component_types", sa.Column("icon_svg", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("component_types", "icon_svg")
