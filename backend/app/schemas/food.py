# ============================================
# EthioCal — Food Schemas
# ============================================
# Request / response shapes for food items
# and AI recognition results.
# ============================================

from datetime import datetime
from typing import Literal

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
    avg_thickness_cm: float | None = None
    density_g_per_cm3: float | None = None
    ai_label: str | None = None
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


class ReferenceObjectInput(BaseModel):
    """Reference object used to convert pixels into real-world dimensions."""

    bbox_width_px: float
    bbox_height_px: float
    known_width_cm: float | None = None
    known_height_cm: float | None = None


class FoodRegionInput(BaseModel):
    """Single detected food region in image coordinates."""

    food_item_id: str
    bbox_width_px: float
    bbox_height_px: float
    mask_area_px: float | None = None
    fill_ratio: float | None = None
    avg_thickness_cm_override: float | None = None


class PortionEstimationRequest(BaseModel):
    """Payload for estimating portion mass from image detections."""

    use_plate_guide: bool = False
    plate_guide: "PlateGuideInput | None" = None
    reference_object: ReferenceObjectInput | None = None  # deprecated, kept for backward compatibility
    foods: list[FoodRegionInput]


class PlateGuideInput(BaseModel):
    """Plate guide metadata used for no-reference-object geometric scaling."""

    shape: Literal["circle", "oval", "rectangle"]
    plate_mask_area_px: float


class PortionFoodProfile(BaseModel):
    """Minimal per-food geometry profile required for portion estimation."""

    id: str
    avg_thickness_cm: float | None = None
    density_g_per_cm3: float | None = None
    serving_size_g: float | None = None


class PortionEstimateItem(BaseModel):
    """Estimated portion metrics for one detected food item."""

    food_item_id: str
    estimated_mass_g: float


class PortionEstimateResponse(BaseModel):
    """Response shape for minimal portion-estimation output."""

    items: list[PortionEstimateItem]
    total_estimated_mass_g: float
    estimation_method: str
