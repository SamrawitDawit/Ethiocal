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

router = APIRouter()


# --- Notification Preferences ---

@router.get("/preferences", response_model=NotificationPreferencesResponse)
async def get_notification_preferences(
    current_user: dict = Depends(get_current_user),
):
    """Get the current user's notification preferences."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    result = (
        supabase.table("notification_preferences")
        .select("*")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    if not result.data:
        # Auto-create default preferences
        insert_result = (
            supabase.table("notification_preferences")
            .insert({"user_id": user_id})
            .execute()
        )
        return insert_result.data[0]

    return result.data


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
    existing = (
        supabase.table("notification_preferences")
        .select("id")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    if not existing.data:
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
    prefs = (
        supabase.table("notification_preferences")
        .select("meal_reminders")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    if prefs.data and not prefs.data.get("meal_reminders", True):
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
    prefs = (
        supabase.table("notification_preferences")
        .select("health_alerts")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    if prefs.data and not prefs.data.get("health_alerts", True):
        return {"message": "Health alerts are disabled.", "alerts_sent": 0}

    # Get user's health conditions
    # Try the new schema first (profile_health_conditions via user_profile)
    user_profile_result = (
        supabase.table("user_profile")
        .select("id")
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    conditions = []
    if user_profile_result.data:
        profile_id = user_profile_result.data["id"]
        phc_result = (
            supabase.table("profile_health_conditions")
            .select("condition_id, condition:health_condition(*)")
            .eq("profile_id", profile_id)
            .execute()
        )
        for entry in phc_result.data:
            cond = entry.get("condition")
            if cond:
                conditions.append(cond)

    # Fallback: also check the old schema (user_health_conditions)
    if not conditions:
        old_result = (
            supabase.table("user_health_conditions")
            .select("health_condition_id, health_conditions(*)")
            .eq("user_id", user_id)
            .execute()
        )
        for entry in old_result.data:
            cond = entry.get("health_conditions")
            if cond:
                conditions.append(cond)

    if not conditions:
        return {"message": "No health conditions configured.", "alerts_sent": 0}

    # Get today's meals and calculate nutrient totals
    from datetime import datetime, timezone

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    start = f"{today}T00:00:00+00:00"
    end = f"{today}T23:59:59+00:00"

    meals_result = (
        supabase.table("meals")
        .select("id")
        .eq("user_id", user_id)
        .gte("created_at", start)
        .lte("created_at", end)
        .execute()
    )

    if not meals_result.data:
        return {"message": "No meals logged today.", "alerts_sent": 0}

    meal_ids = [m["id"] for m in meals_result.data]

    food_items_result = (
        supabase.table("meal_food_items")
        .select("quantity, food_item:food_items(sodium_mg, sugar, fat, cholesterol_mg, calories_per_100g, standard_serving_size)")
        .in_("meal_id", meal_ids)
        .execute()
    )

    # Aggregate nutrients
    nutrient_map = {"Sugar": 0.0, "Sodium": 0.0, "Fat": 0.0, "Cholesterol": 0.0}
    for item in food_items_result.data:
        fi = item.get("food_item", {})
        qty = item.get("quantity", 1.0)
        serving = fi.get("standard_serving_size", 100.0)
        scale = qty * serving / 100.0

        nutrient_map["Sugar"] += (fi.get("sugar", 0) or 0) * scale
        nutrient_map["Sodium"] += (fi.get("sodium_mg", 0) or 0) * scale
        nutrient_map["Fat"] += (fi.get("fat", 0) or 0) * scale
        nutrient_map["Cholesterol"] += (fi.get("cholesterol_mg", 0) or 0) * scale

    # Check thresholds and send alerts
    alerts_sent = 0
    for condition in conditions:
        if not condition:
            continue

        # Support both schemas: old uses restricted_nutrient (singular),
        # new uses restricted_nutrients (plural)
        nutrient = condition.get("restricted_nutrient") or condition.get("restricted_nutrients")
        threshold = condition.get("threshold_amount", 0)
        unit = condition.get("threshold_unit", "g")
        condition_name = condition.get("condition_name", "")
        current = nutrient_map.get(nutrient, 0)

        if current > threshold:
            notification = {
                "user_id": user_id,
                "type": "health_alert",
                "title": f"Health Alert: {condition_name}",
                "body": (
                    f"Your daily {nutrient.lower()} intake ({current:.1f}{unit}) "
                    f"has exceeded the recommended limit of {threshold:.1f}{unit} "
                    f"for {condition_name}. Please watch your diet."
                ),
            }
            supabase.table("notifications").insert(notification).execute()
            alerts_sent += 1

    return {"message": f"{alerts_sent} alert(s) sent.", "alerts_sent": alerts_sent}
