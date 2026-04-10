from datetime import datetime
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


class NutrientSnapshot(BaseModel):
    calories: float = Field(0, ge=0)
    sugar_g: float = Field(0, ge=0)
    sodium_mg: float = Field(0, ge=0)
    cholesterol_mg: float = Field(0, ge=0)
    fat_g: float = Field(0, ge=0)


class FoodHealthEvaluationRequest(BaseModel):
    nutrients: NutrientSnapshot
    consumed_at: Optional[datetime] = None


class CalorieEvaluation(BaseModel):
    daily_goal: Optional[float] = None
    consumed_today: float
    meal_calories: float
    projected_total: float
    exceeds_limit: Optional[bool] = None


class ConditionEvaluation(BaseModel):
    condition_name: str
    restricted_nutrient: str
    threshold_amount: float
    threshold_unit: str
    consumed_today_amount: float
    meal_amount: float
    projected_amount: float
    consumed_amount: float
    consumed_unit: str
    exceeds_limit: bool
    is_close_to_limit: bool


class FoodHealthEvaluationResponse(BaseModel):
    status: Literal["good", "caution", "warning"]
    message: str
    evaluated_at: datetime
    calorie: CalorieEvaluation
    conditions: list[ConditionEvaluation]


class DailyNutrientTotals(BaseModel):
    calories: float = 0
    sugar_g: float = 0
    sodium_mg: float = 0
    cholesterol_mg: float = 0
    fat_g: float = 0


class DailyConditionStatus(BaseModel):
    condition_name: str
    restricted_nutrient: str
    threshold_amount: float
    threshold_unit: str
    consumed_amount: float
    remaining_amount: float
    exceeds_limit: bool


class DailyHealthSummaryResponse(BaseModel):
    date: str
    daily_calorie_goal: Optional[float] = None
    nutrients_consumed: DailyNutrientTotals
    condition_statuses: list[DailyConditionStatus]


class HistoryDaySummary(BaseModel):
    date: str
    status: Literal["good", "caution", "warning"]
    daily_calorie_goal: Optional[float] = None
    calories_consumed: float
    calorie_limit_exceeded: Optional[bool] = None
    condition_alerts: list[str]


class HealthHistoryResponse(BaseModel):
    from_date: str
    to_date: str
    days: list[HistoryDaySummary]