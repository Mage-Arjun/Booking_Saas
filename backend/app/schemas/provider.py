import uuid
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ProviderProfileCreate(BaseModel):
    organization_id: uuid.UUID
    display_name: str = Field(min_length=1, max_length=255)
    bio: str | None = None
    category: str | None = Field(default=None, max_length=100)
    location: dict | None = None
    timezone: str = Field(default="UTC", max_length=50)
    booking_buffer_before_minutes: int = Field(default=0, ge=0)
    booking_buffer_after_minutes: int = Field(default=0, ge=0)
    minimum_notice_hours: int = Field(default=1, ge=0)
    max_advance_days: int = Field(default=30, ge=1)
    cancellation_notice_hours: int = Field(default=24, ge=0)
    allow_same_day_cancellation: bool = False


class ProviderProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=255)
    bio: str | None = None
    category: str | None = Field(default=None, max_length=100)
    location: dict | None = None
    timezone: str | None = Field(default=None, max_length=50)
    is_active: bool | None = None
    booking_buffer_before_minutes: int | None = Field(default=None, ge=0)
    booking_buffer_after_minutes: int | None = Field(default=None, ge=0)
    minimum_notice_hours: int | None = Field(default=None, ge=0)
    max_advance_days: int | None = Field(default=None, ge=1)
    cancellation_notice_hours: int | None = Field(default=None, ge=0)
    allow_same_day_cancellation: bool | None = None


class ProviderProfileResponse(BaseModel):
    id: UUID
    user_id: UUID
    organization_id: UUID
    display_name: str
    bio: str | None
    category: str | None
    location: dict | None
    timezone: str
    is_active: bool
    booking_buffer_before_minutes: int
    booking_buffer_after_minutes: int
    minimum_notice_hours: int
    max_advance_days: int
    cancellation_notice_hours: int
    allow_same_day_cancellation: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ProviderListResponse(BaseModel):
    id: UUID
    display_name: str
    category: str | None
    location: dict | None
    timezone: str
    created_at: datetime

    model_config = {"from_attributes": True}