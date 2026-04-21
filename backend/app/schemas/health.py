from pydantic import BaseModel, Field
from typing import Literal, Optional
from uuid import UUID

class HealthConditionBase(BaseModel):
    condition_name: str
    restricted_nutrient: Literal["Sugar", "Sodium", "Fat", "Cholesterol"]
    threshold_amount: float = Field(gt=0)
    threshold_unit: Literal["mg", "g", "kcal"]

class HealthConditionCreate(HealthConditionBase):
    pass

class HealthConditionUpdate(BaseModel):
    condition_name: Optional[str] = None
    restricted_nutrient: Optional[Literal["Sugar", "Sodium", "Fat", "Cholesterol"]] = None
    threshold_amount: Optional[float] = Field(None, gt=0)
    threshold_unit: Optional[Literal["mg", "g", "kcal"]] = None

class HealthConditionResponse(HealthConditionBase):
    id: UUID

    class Config:
        from_attributes = True


class ConditionProfileFlags(BaseModel):
    has_diabetes: bool = False
    has_hypertension: bool = False
    has_high_cholesterol: bool = False
    diabetes_type: Literal["Type 1", "Type 2"] | None = None
    latest_hba1c: float | None = Field(None, gt=0)


class MealNutrientsInput(BaseModel):
    calories: float = 0.0
    carbs_g: float = 0.0
    saturated_fat_g: float = 0.0
    sodium_mg: float = 0.0
    fiber_g: float = 0.0
    protein_g: float = 0.0


class MealTargetCheckRequest(BaseModel):
    meal_nutrients: MealNutrientsInput


class MealTargetCheckResponse(BaseModel):
    warnings: list[str]
    disclaimer: str
    note: str | None = None
    targets: dict
    current_daily_totals: dict
    projected_daily_totals: dict
    progress: dict