# ============================================
# EthioCal — Food Schemas
# ============================================
# Request / response shapes for food items
# and AI recognition results.
# ============================================

from datetime import datetime

from pydantic import BaseModel


class FoodItemResponse(BaseModel):
    """Full nutritional info for one food item."""
    id: str
    name: str
    name_amharic: str | None = None
    description: str | None = None
    category: str | None = None
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    serving_size_g: float
    created_at: datetime


class FoodRecognitionResult(BaseModel):
    """AI model prediction for a single food item in an image."""
    label: str
    confidence: float
    food_item: FoodItemResponse | None = None  # matched DB entry, if found


class FoodRecognitionResponse(BaseModel):
    """Top-level response from the food recognition endpoint."""
    predictions: list[FoodRecognitionResult]
    image_url: str
