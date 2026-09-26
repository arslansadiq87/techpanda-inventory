"""store whether a location QR code is enabled"""
from alembic import op
import sqlalchemy as sa

revision = "20260927_0007"
down_revision = "20260923_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "locations",
        sa.Column("generate_qr_code", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("locations", "generate_qr_code")
