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
