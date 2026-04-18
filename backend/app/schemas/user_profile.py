from datetime import date, datetime
from typing import List, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.health import HealthConditionResponse

class UserProfileBase(BaseModel):
    full_name: Optional[str] = None
    language_preference: Optional[Literal["English", "Amharic"]] = None
    age: Optional[int] = Field(None, gt=0)
    birthdate: Optional[date] = None
    gender: Optional[Literal["Male", "Female"]] = None
    height: Optional[float] = Field(None, gt=0)
    height_unit: Optional[Literal["cm", "ft"]] = None
    weight: Optional[float] = Field(None, gt=0)
    weight_unit: Optional[Literal["kg", "lbs"]] = None
    activity_level: Optional[Literal["Sedentary", "Lightly Active", "Moderately Active", "Very Active"]] = None
    daily_calorie_goal: Optional[float] = Field(None, gt=0)

class UserProfileUpdate(UserProfileBase):
    """Payload for updating profile. Inherits fields + adds health_condition_ids."""
    health_condition_ids: Optional[List[UUID]] = None

class UserProfileResponse(UserProfileBase):
    id: UUID
    email: str 
    full_name: str
    role: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    health_conditions: List[HealthConditionResponse] = []

    class Config:
        from_attributes = True
