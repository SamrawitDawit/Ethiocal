# ============================================
# EthioCal — Meal Schemas
# ============================================
# Request / response shapes for meals and
# meal entries.
# ============================================

from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.food import FoodItemResponse, IngredientResponse


MealType = Literal["breakfast", "lunch", "dinner", "snack"]


# --- Meal Food Item Entry ---

class MealFoodItemEntry(BaseModel):
    """A food item to add to a meal.

    For text-based meals: quantity is a multiplier (1.0, 1.5, etc)
    For image-based meals: quantity is portion_grams (actual grams from AI)
    """
    food_item_id: str
    quantity: float = 1.0


class MealFoodItemResponse(BaseModel):
    """Food item in a meal with calculated calories."""
    id: str
    meal_id: str
    food_item_id: str
    quantity: float
    total_calories: float
    food_item: FoodItemResponse | None = None
    created_at: datetime


# --- Meal Ingredient Entry ---

class MealIngredientEntry(BaseModel):
    """A cooking ingredient to add to a meal (optional)."""
    ingredient_id: str
    quantity: float = 1.0


class MealIngredientResponse(BaseModel):
    """Ingredient in a meal with calculated calories."""
    id: str
    meal_id: str
    ingredient_id: str
    quantity: float
    total_calories: float
    ingredient: IngredientResponse | None = None
    created_at: datetime


# --- Meal Creation (Step 1: Food Items) ---

class MealCreate(BaseModel):
    """Create a meal with selected food items."""
    meal_type: MealType
    food_items: list[MealFoodItemEntry]
    portion_size: float = 1.0
    image_url: str | None = None  # Optional image URL from food recognition


class MealCreateResponse(BaseModel):
    """Response after creating meal with food items."""
    id: str
    user_id: str
    meal_type: str
    portion_size: float
    total_calories: float
    image_url: str | None = None
    food_items: list[MealFoodItemResponse]
    created_at: datetime


# --- Add Ingredients (Step 2: Optional) ---

class MealAddIngredients(BaseModel):
    """Add cooking ingredients to an existing meal (optional step)."""
    ingredients: list[MealIngredientEntry]


class MealAddIngredientsResponse(BaseModel):
    """Response after adding ingredients."""
    meal_id: str
    ingredients: list[MealIngredientResponse]
    added_calories: float
    new_total_calories: float


# --- Full Meal Response ---

class MealResponse(BaseModel):
    """Complete meal with food items and optional ingredients."""
    id: str
    user_id: str
    meal_type: str
    portion_size: float
    total_calories: float
    image_url: str | None = None
    food_items: list[MealFoodItemResponse] = []
    ingredients: list[MealIngredientResponse] = []
    created_at: datetime


# --- Nutrition Analysis ---

class NutrientBreakdown(BaseModel):
    """Detailed nutrient breakdown."""
    calories: float
    carbohydrates: float
    protein: float
    fat: float
    fiber: float
    sodium_mg: float = 0.0
    sugar: float = 0.0
    cholesterol_mg: float = 0.0


class MealNutritionAnalysis(BaseModel):
    """Full nutritional analysis of a meal."""
    meal_id: str
    meal_type: str
    nutrients: NutrientBreakdown
    food_items_count: int
    ingredients_count: int
