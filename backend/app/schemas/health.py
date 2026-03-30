from pydantic import BaseModel, Field
from typing import Literal, Optional
from uuid import UUID

class HealthConditionBase(BaseModel):
    condition_name: str
    restricted_nutrients: Literal["Sugar", "Sodium", "Fat", "Cholesterol"]
    threshold_amount: float = Field(gt=0)
    threshold_unit: Literal["mg", "g", "kcal"]

class HealthConditionCreate(HealthConditionBase):
    pass

class HealthConditionUpdate(BaseModel):
    condition_name: Optional[str] = None
    restricted_nutrients: Optional[Literal["Sugar", "Sodium", "Fat", "Cholesterol"]] = None
    threshold_amount: Optional[float] = Field(None, gt=0)
    threshold_unit: Optional[Literal["mg", "g", "kcal"]] = None

class HealthConditionResponse(HealthConditionBase):
    id: UUID

    class Config:
        from_attributes = True