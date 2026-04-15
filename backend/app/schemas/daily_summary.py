from pydantic import BaseModel
from datetime import date
from typing import Optional

class DailySummaryBase(BaseModel):
    date: date
    total_calories: int = 0
    total_protein: float = 0.0
    total_carbohydrates: float = 0.0
    total_fat: float = 0.0
    breakfast_calories: int = 0
    lunch_calories: int = 0
    dinner_calories: int = 0
    snack_calories: int = 0
    meal_count: int = 0
    daily_calorie_goal: int = 2000

class DailySummaryCreate(DailySummaryBase):
    user_id: str

class DailySummaryUpdate(BaseModel):
    total_calories: Optional[int] = None
    total_protein: Optional[float] = None
    total_carbohydrates: Optional[float] = None
    total_fat: Optional[float] = None
    breakfast_calories: Optional[int] = None
    lunch_calories: Optional[int] = None
    dinner_calories: Optional[int] = None
    snack_calories: Optional[int] = None
    meal_count: Optional[int] = None
    daily_calorie_goal: Optional[int] = None

class DailySummaryResponse(DailySummaryBase):
    id: int
    user_id: str
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

class DailySummaryDashboard(BaseModel):
    """Optimized response for dashboard - combines all needed data in one call"""
    date: str
    total_calories: int
    total_protein: float
    total_carbohydrates: float
    total_fat: float
    breakfast_calories: int
    lunch_calories: int
    dinner_calories: int
    snack_calories: int
    meal_count: int
    daily_calorie_goal: int
    meal_breakdown: dict
    success: bool = True
