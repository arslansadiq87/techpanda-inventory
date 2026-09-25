"""add project kit tables"""
from alembic import op
import sqlalchemy as sa

revision = "20260923_0006"
down_revision = "20260920_0005"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table("project_kits",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("workspace_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=220), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
    )
    op.create_table("project_kit_lines",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("project_kit_id", sa.String(length=36), nullable=False),
        sa.Column("component_id", sa.String(length=36), nullable=False),
        sa.Column("quantity", sa.Numeric(18, 4), nullable=False),
        sa.Column("unit", sa.String(length=32), nullable=False, server_default="Pieces"),
        sa.Column("notes", sa.Text()),
        sa.ForeignKeyConstraint(["project_kit_id"], ["project_kits.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["component_id"], ["components.id"]),
    )

def downgrade() -> None:
    op.drop_table("project_kit_lines")
    op.drop_table("project_kits")
