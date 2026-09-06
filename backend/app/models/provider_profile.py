import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class ProviderProfile(TimestampMixin, Base):
    __tablename__ = "provider_profiles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    organization_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("organizations.id"), nullable=False, index=True
    )
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    bio: Mapped[str | None] = mapped_column(String, nullable=True)
    category: Mapped[str | None] = mapped_column(String, nullable=True)
    location: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    timezone: Mapped[str] = mapped_column(String, nullable=False, default="UTC")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    booking_buffer_before_minutes: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    booking_buffer_after_minutes: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    minimum_notice_hours: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    max_advance_days: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    cancellation_notice_hours: Mapped[int] = mapped_column(
        Integer, nullable=False, default=24
    )
    allow_same_day_cancellation: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
