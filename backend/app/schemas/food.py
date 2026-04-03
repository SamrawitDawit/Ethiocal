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
    calories_per_100g: float
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
    calories_per_100g: float | None = None
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
    calories_per_100g: float
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
    calories_per_100g: float = 0.0
    carbohydrates: float = 0.0
    protein: float = 0.0
    fat: float = 0.0
    fiber: float = 0.0
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0


class IngredientResponse(BaseModel):
    """Ingredient nutritional information."""
    id: str
    name: str
    name_amharic: str | None = None
    category: str | None = None
    calories_per_100g: float
    carbohydrates: float
    protein: float
    fat: float
    fiber: float
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0
    created_at: datetime


class FoodItemIngredientResponse(BaseModel):
    """Standard ingredient for a food item with quantity."""
    id: str
    food_item_id: str
    ingredient_id: str
    quantity_grams: float
    ingredient: IngredientResponse
    created_at: datetime


class FoodItemWithIngredientsResponse(BaseModel):
    """Food item with its standard ingredients."""
    food_item: FoodItemResponse
    ingredients: list[FoodItemIngredientResponse]


# --- AI Recognition ---


class BoundingBox(BaseModel):
    """Bounding box coordinates for a detected food item."""
    x1: float  # Top-left x coordinate
    y1: float  # Top-left y coordinate
    x2: float  # Bottom-right x coordinate
    y2: float  # Bottom-right y coordinate
    width: float
    height: float


class SegmentationMask(BaseModel):
    """Segmentation mask data for a detected food item."""
    polygon: list[list[float]]  # List of [x, y] coordinate pairs forming the mask polygon
    area: float | None = None  # Area of the mask in pixels


class FoodRecognitionResult(BaseModel):
    """AI model prediction for a single food item in an image."""
    label: str
    confidence: float
    bounding_box: BoundingBox | None = None
    mask: SegmentationMask | None = None
    food_item: FoodItemResponse | None = None  # matched DB entry, if found


class FoodRecognitionResponse(BaseModel):
    """Top-level response from the food recognition endpoint."""
    predictions: list[FoodRecognitionResult]
    image_url: str
    image_width: int | None = None
    image_height: int | None = None
