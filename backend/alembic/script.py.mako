"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "${up_revision}"
down_revision: Union[str, None] = "${down_revision}"
branch_labels: Union[str, Sequence[str], None] = ${branch_labels}
depends_on: Union[str, Sequence[str], None] = ${depends_on}


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
