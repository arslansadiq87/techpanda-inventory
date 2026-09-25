"""add component price

Revision ID: 20260920_0005
Revises: 20260720_0004
Create Date: 2026-09-20 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260920_0005"
down_revision = "20260720_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("components", sa.Column("price", sa.Numeric(precision=18, scale=4), nullable=True))


def downgrade() -> None:
    op.drop_column("components", "price")

