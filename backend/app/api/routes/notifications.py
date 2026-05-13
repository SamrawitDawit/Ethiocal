from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.notification import (
    NotificationPreferencesUpdate,
    NotificationPreferencesResponse,
    NotificationResponse,
    SendReminderRequest,
    SendHealthAlertRequest,
)
from app.services.user_health_conditions import get_user_health_conditions

router = APIRouter()


def _load_notification_preferences(supabase, user_id: str, *, create_if_missing: bool = False) -> dict:
    result = (
        supabase.table("notification_preferences")
        .select("*")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    preferences = (getattr(result, "data", None) or {}) if result else {}
    if preferences or not create_if_missing:
        return preferences

    insert_result = (
        supabase.table("notification_preferences")
        .insert({"user_id": user_id})
        .execute()
    )
    inserted_rows = (getattr(insert_result, "data", None) or []) if insert_result else []
    return inserted_rows[0] if inserted_rows else {}


def _canonical_nutrient_name(nutrient: str | None) -> str | None:
    normalized = str(nutrient or "").strip().lower()
    if normalized in {"carbohydrate", "carbohydrates", "carb", "carbs"}:
        return "carbohydrates"
    if normalized in {"sugar", "sugars"}:
        return "sugar"
    if normalized in {"sodium", "sodium_mg"}:
        return "sodium"
    if normalized in {"fat", "total_fat"}:
        return "fat"
    if normalized in {"cholesterol", "cholesterol_mg"}:
        return "cholesterol"
    return None


def _build_daily_nutrient_totals(supabase, user_id: str, start: str, end: str):
    meals_result = (
        supabase.table("meals")
        .select("id, image_url")
        .eq("user_id", user_id)
        .gte("created_at", start)
        .lte("created_at", end)
        .execute()
    )

    meals = meals_result.data or []
    if not meals:
        return None, {
            "carbohydrates": 0.0,
            "sugar": 0.0,
            "sodium": 0.0,
            "fat": 0.0,
            "cholesterol": 0.0,
        }

    meal_map = {meal["id"]: meal for meal in meals}
    meal_ids = list(meal_map.keys())

    totals = {
        "carbohydrates": 0.0,
        "sugar": 0.0,
        "sodium": 0.0,
        "fat": 0.0,
        "cholesterol": 0.0,
    }

    food_items_result = (
        supabase.table("meal_food_items")
        .select(
            "meal_id, quantity, food_item:food_items(carbohydrates, sugar, sodium_mg, fat, cholesterol_mg, standard_serving_size)"
        )
        .in_("meal_id", meal_ids)
        .execute()
    )

    for item in food_items_result.data or []:
        food_item = item.get("food_item") or {}
        meal = meal_map.get(item.get("meal_id"), {})
        quantity = float(item.get("quantity") or 0.0)
        if meal.get("image_url"):
            scale = quantity / 100.0
        else:
            scale = quantity * float(food_item.get("standard_serving_size", 100.0)) / 100.0

        totals["carbohydrates"] += scale * float(food_item.get("carbohydrates", 0.0))
        totals["sugar"] += scale * float(food_item.get("sugar", 0.0))
        totals["sodium"] += scale * float(food_item.get("sodium_mg", 0.0))
        totals["fat"] += scale * float(food_item.get("fat", 0.0))
        totals["cholesterol"] += scale * float(food_item.get("cholesterol_mg", 0.0))

    meal_ingredients_result = (
        supabase.table("meal_ingredients")
        .select(
            "meal_id, quantity, ingredient:ingredients(carbohydrates, sugar, sodium_mg, fat, cholesterol_mg)"
        )
        .in_("meal_id", meal_ids)
        .execute()
    )

    for item in meal_ingredients_result.data or []:
        ingredient = item.get("ingredient") or {}
        scale = float(item.get("quantity") or 0.0) / 100.0
        totals["carbohydrates"] += scale * float(ingredient.get("carbohydrates", 0.0))
        totals["sugar"] += scale * float(ingredient.get("sugar", 0.0))
        totals["sodium"] += scale * float(ingredient.get("sodium_mg", 0.0))
        totals["fat"] += scale * float(ingredient.get("fat", 0.0))
        totals["cholesterol"] += scale * float(ingredient.get("cholesterol_mg", 0.0))

    meal_food_item_ingredients_result = (
        supabase.table("meal_food_item_ingredients")
        .select(
            "meal_id, quantity_diff, ingredient:ingredients(carbohydrates, sugar, sodium_mg, fat, cholesterol_mg)"
        )
        .in_("meal_id", meal_ids)
        .execute()
    )

    for item in meal_food_item_ingredients_result.data or []:
        ingredient = item.get("ingredient") or {}
        scale = float(item.get("quantity_diff") or 0.0) / 100.0
        totals["carbohydrates"] += scale * float(ingredient.get("carbohydrates", 0.0))
        totals["sugar"] += scale * float(ingredient.get("sugar", 0.0))
        totals["sodium"] += scale * float(ingredient.get("sodium_mg", 0.0))
        totals["fat"] += scale * float(ingredient.get("fat", 0.0))
        totals["cholesterol"] += scale * float(ingredient.get("cholesterol_mg", 0.0))

    return meal_ids, totals


# --- Notification Preferences ---

@router.get("/preferences", response_model=NotificationPreferencesResponse)
async def get_notification_preferences(
    current_user: dict = Depends(get_current_user),
):
    """Get the current user's notification preferences."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    return _load_notification_preferences(supabase, user_id, create_if_missing=True)


@router.patch("/preferences", response_model=NotificationPreferencesResponse)
async def update_notification_preferences(
    payload: NotificationPreferencesUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update the current user's notification preferences."""
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update.",
        )

    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Ensure preferences row exists
    existing = _load_notification_preferences(supabase, user_id)

    if not existing:
        insert_result = (
            supabase.table("notification_preferences")
            .insert({"user_id": user_id, **update_data})
            .execute()
        )
        return insert_result.data[0]

    result = (
        supabase.table("notification_preferences")
        .update(update_data)
        .eq("user_id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update notification preferences.",
        )

    return result.data[0]


# --- Notification Log ---

@router.get("/", response_model=list[NotificationResponse])
async def get_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
    current_user: dict = Depends(get_current_user),
):
    """Get the current user's notifications."""
    supabase = get_supabase_admin()

    query = (
        supabase.table("notifications")
        .select("*")
        .eq("user_id", current_user["id"])
        .order("created_at", desc=True)
    )

    if unread_only:
        query = query.eq("is_read", False)

    result = query.range(skip, skip + limit - 1).execute()
    return result.data


@router.patch("/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Mark a notification as read."""
    supabase = get_supabase_admin()

    result = (
        supabase.table("notifications")
        .update({"is_read": True})
        .eq("id", notification_id)
        .eq("user_id", current_user["id"])
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found.",
        )

    return {"message": "Notification marked as read."}


@router.patch("/read-all")
async def mark_all_notifications_read(
    current_user: dict = Depends(get_current_user),
):
    """Mark all notifications as read."""
    supabase = get_supabase_admin()

    supabase.table("notifications").update({"is_read": True}).eq(
        "user_id", current_user["id"]
    ).eq("is_read", False).execute()

    return {"message": "All notifications marked as read."}


@router.get("/unread-count")
async def get_unread_count(
    current_user: dict = Depends(get_current_user),
):
    """Get count of unread notifications."""
    supabase = get_supabase_admin()

    result = (
        supabase.table("notifications")
        .select("id", count="exact")
        .eq("user_id", current_user["id"])
        .eq("is_read", False)
        .execute()
    )

    return {"unread_count": result.count or 0}


# --- Trigger Notifications ---

@router.post("/send-reminder")
async def send_reminder(
    current_user: dict = Depends(get_current_user),
):
    """Send a meal reminder notification to the current user."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Check if user has meal reminders enabled
    prefs = _load_notification_preferences(supabase, user_id)

    if not prefs.get("meal_reminders", True):
        return {"message": "Meal reminders are disabled for this user."}

    # Create the notification
    notification = {
        "user_id": user_id,
        "type": "meal_reminder",
        "title": "Time to log your meal!",
        "body": "Don't forget to log your meal to stay on track with your nutrition goals.",
    }

    result = supabase.table("notifications").insert(notification).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send reminder.",
        )

    return {"message": "Reminder sent.", "notification": result.data[0]}


@router.post("/check-health-alerts")
async def check_health_alerts(
    current_user: dict = Depends(get_current_user),
):
    """Check current user's daily intake against health condition thresholds
    and send alerts if limits are exceeded."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Check if user has health alerts enabled
    prefs = _load_notification_preferences(supabase, user_id)

    if not prefs.get("health_alerts", True):
        return {"message": "Health alerts are disabled.", "alerts_sent": 0}

    conditions = get_user_health_conditions(supabase, user_id)

    if not conditions:
        return {"message": "No health conditions configured.", "alerts_sent": 0}

    # Get today's meals and calculate nutrient totals
    from datetime import datetime, timezone

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    start = f"{today}T00:00:00+00:00"
    end = f"{today}T23:59:59+00:00"

    meal_ids, nutrient_totals = _build_daily_nutrient_totals(supabase, user_id, start, end)

    if not meal_ids:
        return {"message": "No meals logged today.", "alerts_sent": 0}

    existing_alerts_result = (
        supabase.table("notifications")
        .select("title")
        .eq("user_id", user_id)
        .eq("type", "health_alert")
        .gte("created_at", start)
        .lte("created_at", end)
        .execute()
    )
    existing_titles = {
        str(item.get("title") or "") for item in (existing_alerts_result.data or [])
    }

    # Check thresholds and send alerts
    alerts_sent = 0
    for condition in conditions:
        if not condition:
            continue

        # Support both schemas: old uses restricted_nutrient (singular),
        # new uses restricted_nutrients (plural)
        nutrient = condition.get("restricted_nutrient") or condition.get("restricted_nutrients")
        canonical_nutrient = _canonical_nutrient_name(nutrient)
        if canonical_nutrient is None:
            continue

        threshold = float(condition.get("threshold_amount") or 0.0)
        unit = condition.get("threshold_unit", "g")
        condition_name = condition.get("condition_name", "")
        current = float(nutrient_totals.get(canonical_nutrient, 0.0))

        title = f"Health Alert: {condition_name}"

        if current > threshold and title not in existing_titles:
            notification = {
                "user_id": user_id,
                "type": "health_alert",
                "title": title,
                "body": (
                    f"Your daily {str(nutrient).lower()} intake ({current:.1f}{unit}) "
                    f"has exceeded the recommended limit of {threshold:.1f}{unit} "
                    f"for {condition_name}. Please watch your diet."
                ),
            }
            supabase.table("notifications").insert(notification).execute()
            alerts_sent += 1
            existing_titles.add(title)

    return {"message": f"{alerts_sent} alert(s) sent.", "alerts_sent": alerts_sent}
