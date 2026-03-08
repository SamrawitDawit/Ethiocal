# ============================================
# EthioCal — Meal Routes
# ============================================
# POST /              — create a meal
# POST /log           — log a food item to a meal
# GET  /history       — user's meal history
# GET  /daily-summary — calorie summary for a day
# ============================================

from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.meal import (
    MealCreate, MealResponse,
    MealLogCreate, MealLogResponse,
    DailySummary,
)

router = APIRouter()

VALID_MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}


@router.post("/", response_model=MealResponse, status_code=status.HTTP_201_CREATED)
async def create_meal(
    payload: MealCreate,
    current_user: dict = Depends(get_current_user),
):
    """Create a new meal event (breakfast / lunch / dinner / snack)."""
    if payload.meal_type not in VALID_MEAL_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"meal_type must be one of {VALID_MEAL_TYPES}.",
        )

    supabase = get_supabase_admin()
    result = (
        supabase.table("meals")
        .insert({
            "user_id": current_user["id"],
            "meal_type": payload.meal_type,
        })
        .execute()
    )

    meal = result.data[0]
    meal["meal_logs"] = []  # new meal has no logs yet
    return meal


@router.post("/log", response_model=MealLogResponse, status_code=status.HTTP_201_CREATED)
async def log_food_item(
    payload: MealLogCreate,
    current_user: dict = Depends(get_current_user),
):
    """Log a food item to an existing meal.

    Calculates total_calories as quantity * food_item.calories.
    """
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Verify the meal belongs to the current user
    meal_result = (
        supabase.table("meals")
        .select("id, user_id")
        .eq("id", payload.meal_id)
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )
    if not meal_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found.",
        )

    # Get the food item for calorie calculation
    food_result = (
        supabase.table("food_items")
        .select("*")
        .eq("id", payload.food_item_id)
        .maybe_single()
        .execute()
    )
    if not food_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Food item not found.",
        )

    food_item = food_result.data
    total_calories = payload.quantity * food_item["calories"]

    # Insert the meal log
    log_result = (
        supabase.table("meal_logs")
        .insert({
            "user_id": user_id,
            "meal_id": payload.meal_id,
            "food_item_id": payload.food_item_id,
            "quantity": payload.quantity,
            "total_calories": total_calories,
        })
        .execute()
    )

    # Attach the food_item data to the response
    log_data = log_result.data[0]
    log_data["food_item"] = food_item
    return log_data


@router.get("/history", response_model=list[MealResponse])
async def get_meal_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    """Return the current user's meal history (newest first).

    Uses Supabase's nested select to include meal_logs
    and their related food_items in a single query.
    """
    supabase = get_supabase_admin()
    result = (
        supabase.table("meals")
        .select("*, meal_logs(*, food_item:food_items(*))")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
        .range(skip, skip + limit - 1)
        .execute()
    )

    # Rename the nested 'food_item' key from the join to match our schema
    meals = result.data
    for meal in meals:
        for log in meal.get("meal_logs", []):
            log["food_item"] = log.pop("food_item", None)

    return meals


@router.get("/daily-summary", response_model=DailySummary)
async def daily_summary(
    day: date = Query(default=None, description="Date in YYYY-MM-DD format. Defaults to today."),
    current_user: dict = Depends(get_current_user),
):
    """Get a calorie summary for a specific date."""
    target = day or date.today()
    start = f"{target}T00:00:00+00:00"
    end = f"{target}T23:59:59+00:00"

    supabase = get_supabase_admin()
    result = (
        supabase.table("meals")
        .select("*, meal_logs(*, food_item:food_items(*))")
        .eq("user_id", current_user["id"])
        .gte("created_at", start)
        .lte("created_at", end)
        .order("created_at")
        .execute()
    )

    meals = result.data

    # Rename nested key and compute total
    total = 0.0
    for meal in meals:
        for log in meal.get("meal_logs", []):
            log["food_item"] = log.pop("food_item", None)
            total += log.get("total_calories", 0.0)

    return DailySummary(
        date=target.isoformat(),
        total_calories=total,
        calorie_goal=current_user["daily_calorie_goal"],
        meals=meals,
    )
