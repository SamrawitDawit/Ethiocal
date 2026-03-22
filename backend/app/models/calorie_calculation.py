from pydantic import BaseModel
from typing import List


class FoodItem(BaseModel):
    name: str
    grams: float


class CalorieRequest(BaseModel):
    foods: List[FoodItem]


class FoodCalorieResponse(BaseModel):
    food: str
    grams: float
    calories: float


class CalorieResponse(BaseModel):
    foods: List[FoodCalorieResponse]
    total_calories: float