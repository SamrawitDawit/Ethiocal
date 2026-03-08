# ============================================
# EthioCal — Meal Schemas
# ============================================
# Request / response shapes for meals and
# meal log entries.
# ============================================

from datetime import datetime

from pydantic import BaseModel

from app.schemas.food import FoodItemResponse


# --- Meal creation ---

class MealCreate(BaseModel):
    """Create a new meal event."""
    meal_type: str  # "breakfast" | "lunch" | "dinner" | "snack"


# --- Meal log entry ---

class MealLogCreate(BaseModel):
    """Log a food item eaten in a meal."""
    meal_id: str
    food_item_id: str
    quantity: float = 1.0


class MealLogResponse(BaseModel):
    """Single meal log entry with food details."""
    id: str
    meal_id: str
    food_item_id: str
    quantity: float
    total_calories: float
    food_item: FoodItemResponse | None = None
    created_at: datetime


# --- Meal response ---

class MealResponse(BaseModel):
    """A meal with its logged food items."""
    id: str
    user_id: str
    meal_type: str
    image_url: str | None = None
    created_at: datetime
    meal_logs: list[MealLogResponse] = []


# --- Daily summary ---

class DailySummary(BaseModel):
    """Aggregated calorie intake for a single day."""
    date: str
    total_calories: float
    calorie_goal: float
    meals: list[MealResponse]
