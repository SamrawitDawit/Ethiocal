# ============================================
# EthioCal — Food Schemas
# ============================================
# Request / response shapes for food items
# and ingredients.
# ============================================

from datetime import datetime

from pydantic import BaseModel


# --- Food Items ---

class FoodItemCreate(BaseModel):
    """Create a new food item (admin only)."""
    name: str
    name_amharic: str | None = None
    description: str | None = None
    category: str | None = None
    standard_serving_size: float = 100.0
    calories_per_serving: float
    carbohydrates: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    fiber: float = 0.0
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0
    source: str = "manual"
    ai_label: str | None = None


class FoodItemUpdate(BaseModel):
    """Update food item (admin only)."""
    name: str | None = None
    name_amharic: str | None = None
    description: str | None = None
    category: str | None = None
    standard_serving_size: float | None = None
    calories_per_serving: float | None = None
    carbohydrates: float | None = None
    protein: float | None = None
    fat: float | None = None
    fiber: float | None = None
    source: str | None = None


class FoodItemResponse(BaseModel):
    """Full nutritional info for one food item."""
    id: str
    name: str
    name_amharic: str | None = None
    description: str | None = None
    category: str | None = None
    standard_serving_size: float
    calories_per_serving: float
    carbohydrates: float
    protein: float
    fat: float
    fiber: float
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0
    source: str = "manual"
    ai_label: str | None = None
    created_at: datetime


# --- Ingredients ---

class IngredientCreate(BaseModel):
    """Create a new ingredient (admin only)."""
    name: str
    name_amharic: str | None = None
    category: str | None = None
    standard_serving_size: float = 10.0
    calories_per_serving: float
    carbohydrates: float = 0.0
    protein: float = 0.0
    fat: float = 0.0


class IngredientResponse(BaseModel):
    """Cooking ingredient data."""
    id: str
    name: str
    name_amharic: str | None = None
    category: str | None = None
    standard_serving_size: float
    calories_per_serving: float
    carbohydrates: float
    protein: float
    fat: float
    created_at: datetime


# --- Food Item Standard Ingredients ---

class FoodItemIngredientResponse(BaseModel):
    """Standard ingredient in a food item."""
    id: str
    food_item_id: str
    ingredient_id: str
    standard_quantity: float
    ingredient: IngredientResponse | None = None
    created_at: datetime


class FoodItemWithIngredientsResponse(BaseModel):
    """Food item with its standard ingredients."""
    id: str
    name: str
    name_amharic: str | None = None
    description: str | None = None
    category: str | None = None
    standard_serving_size: float
    calories_per_serving: float
    carbohydrates: float
    protein: float
    fat: float
    fiber: float
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0
    source: str = "manual"
    ai_label: str | None = None
    created_at: datetime
    standard_ingredients: list[FoodItemIngredientResponse] = []


# --- AI Recognition ---

class FoodRecognitionResult(BaseModel):
    """AI model prediction for a single food item in an image."""
    label: str
    confidence: float
    food_item: FoodItemResponse | None = None


class FoodRecognitionResponse(BaseModel):
    """Top-level response from the food recognition endpoint."""
    predictions: list[FoodRecognitionResult]
    image_url: str
