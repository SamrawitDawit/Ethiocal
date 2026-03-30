from pydantic import BaseModel, Field
from typing import Literal, List, Optional
from uuid import UUID
from app.schemas.health import HealthConditionResponse

class UserProfileBase(BaseModel):
    age: Optional[int] = Field(None, gt=0)
    gender: Optional[Literal["Male", "Female"]] = None
    height: Optional[float] = Field(None, gt=0)
    height_unit: Optional[Literal["cm", "ft"]] = None
    weight: Optional[float] = Field(None, gt=0)
    weight_unit: Optional[Literal["kg", "lbs"]] = None
    activity_level: Optional[Literal["Sedentary", "Light Active", "Moderately Active", "Very Active"]] = None
    daily_calorie_goal: Optional[float] = Field(None, gt=0)

class UserProfileUpdate(UserProfileBase):
    """Payload for updating profile. Inherits fields + adds health_condition_ids."""
    health_condition_ids: Optional[List[UUID]] = None

class UserProfileResponse(UserProfileBase):
    id: UUID          # profileId
    user_id: UUID     # userId (Foreign Key to User)
    health_conditions: List[HealthConditionResponse] = []

    class Config:
        from_attributes = True
