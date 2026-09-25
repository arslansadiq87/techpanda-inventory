"""initial schema

Revision ID: 20260711_0001
Revises:
Create Date: 2026-07-11 22:35:00
"""

from alembic import op

from app.models import Base

revision = "20260711_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
