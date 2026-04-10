from datetime import date, datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import List
from uuid import UUID
from app.db.supabase import get_supabase_admin
from app.schemas.health import (
    CalorieEvaluation,
    ConditionEvaluation,
    DailyConditionStatus,
    DailyHealthSummaryResponse,
    DailyNutrientTotals,
    FoodHealthEvaluationRequest,
    FoodHealthEvaluationResponse,
    HealthConditionCreate,
    HealthConditionResponse,
    HealthHistoryResponse,
    HistoryDaySummary,
    HealthConditionUpdate,
)
from app.core.dependencies import get_current_user, get_current_admin

router = APIRouter()


def _convert_unit(amount: float, from_unit: str, to_unit: str) -> float:
    if from_unit == to_unit:
        return amount
    if from_unit == "g" and to_unit == "mg":
        return amount * 1000
    if from_unit == "mg" and to_unit == "g":
        return amount / 1000
    return amount


def _status_message(status: str) -> str:
    if status == "warning":
        return "This food may exceed your current health limits."
    if status == "caution":
        return "This food is close to your limits. Consider a smaller portion."
    return "This food fits your current health targets."


def _day_bounds(day: date) -> tuple[datetime, datetime]:
    start = datetime(day.year, day.month, day.day, tzinfo=timezone.utc)
    end = start + timedelta(days=1) - timedelta(microseconds=1)
    return start, end


def _parse_day_or_today(day_text: str | None) -> date:
    if not day_text:
        return datetime.now(timezone.utc).date()
    try:
        return datetime.strptime(day_text, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="date must be YYYY-MM-DD")


def _activity_multiplier(activity_level: str | None) -> float:
    mapping = {
        "Sedentary": 1.2,
        "Light Active": 1.375,
        "Lightly Active": 1.375,
        "Moderately Active": 1.55,
        "Very Active": 1.725,
    }
    return mapping.get(activity_level or "", 1.2)


def _calculate_recommended_calorie_goal(profile: dict) -> float | None:
    age = profile.get("age")
    gender = profile.get("gender")
    height = profile.get("height")
    weight = profile.get("weight")
    if not all([age, gender, height, weight]):
        return None

    height_cm = float(height)
    weight_kg = float(weight)
    if profile.get("height_unit") == "ft":
        height_cm = height_cm * 30.48
    if profile.get("weight_unit") == "lbs":
        weight_kg = weight_kg / 2.20462

    if gender == "Male":
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * float(age) + 5
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * float(age) - 161

    return round(bmr * _activity_multiplier(profile.get("activity_level")), 2)


def _resolve_daily_calorie_goal(profile: dict) -> float | None:
    explicit_goal = profile.get("daily_calorie_goal")
    if explicit_goal and explicit_goal > 0:
        return float(explicit_goal)
    # Intentionally do not auto-recommend a calorie goal for enforcement.
    # We keep formula logic in _calculate_recommended_calorie_goal for future optional UX use.
    return None


def _fetch_user_conditions(supabase, user_id: str) -> list[dict]:
    result = (
        supabase.table("user_health_conditions")
        .select("health_conditions(*)")
        .eq("user_id", user_id)
        .execute()
    )
    return [
        row.get("health_conditions")
        for row in (result.data or [])
        if row.get("health_conditions")
    ]


def _fetch_daily_nutrients(supabase, user_id: str, day: date) -> DailyNutrientTotals:
    day_start, day_end = _day_bounds(day)
    meals_result = (
        supabase.table("meals")
        .select("id,total_calories")
        .eq("user_id", user_id)
        .gte("created_at", day_start.isoformat())
        .lte("created_at", day_end.isoformat())
        .execute()
    )

    meals = meals_result.data or []
    meal_ids = [meal["id"] for meal in meals]
    calories = sum((meal.get("total_calories") or 0.0) for meal in meals)

    totals = DailyNutrientTotals(calories=calories)
    if not meal_ids:
        return totals

    meal_food_result = (
        supabase.table("meal_food_items")
        .select("quantity, food_item:food_items(standard_serving_size, sugar, sodium_mg, cholesterol_mg, fat)")
        .in_("meal_id", meal_ids)
        .execute()
    )

    sugar = 0.0
    sodium = 0.0
    cholesterol = 0.0
    fat = 0.0

    for item in meal_food_result.data or []:
        food = item.get("food_item") or {}
        quantity = float(item.get("quantity") or 0)
        serving_size = float(food.get("standard_serving_size") or 100)
        factor = quantity * serving_size / 100.0

        sugar += factor * float(food.get("sugar") or 0)
        sodium += factor * float(food.get("sodium_mg") or 0)
        cholesterol += factor * float(food.get("cholesterol_mg") or 0)
        fat += factor * float(food.get("fat") or 0)

    totals.sugar_g = sugar
    totals.sodium_mg = sodium
    totals.cholesterol_mg = cholesterol
    totals.fat_g = fat
    return totals


def _evaluate_conditions(
    consumed_today: DailyNutrientTotals,
    incoming_meal: DailyNutrientTotals,
    conditions: list[dict],
) -> list[ConditionEvaluation]:
    nutrient_map = {
        "Sugar": (consumed_today.sugar_g, incoming_meal.sugar_g, "g"),
        "Sodium": (consumed_today.sodium_mg, incoming_meal.sodium_mg, "mg"),
        "Cholesterol": (consumed_today.cholesterol_mg, incoming_meal.cholesterol_mg, "mg"),
        "Fat": (consumed_today.fat_g, incoming_meal.fat_g, "g"),
    }
    allowed_conditions = {"Diabetes", "Hypertension", "Heart Disease"}

    evaluations: list[ConditionEvaluation] = []
    for condition in conditions:
        condition_name = condition.get("condition_name")
        if condition_name not in allowed_conditions:
            continue

        restricted_nutrient = condition.get("restricted_nutrient")
        if restricted_nutrient not in nutrient_map:
            continue

        consumed_today_amount, meal_amount, nutrient_unit = nutrient_map[restricted_nutrient]
        threshold_amount = float(condition.get("threshold_amount") or 0)
        threshold_unit = condition.get("threshold_unit") or nutrient_unit

        consumed_today_in_threshold = _convert_unit(consumed_today_amount, nutrient_unit, threshold_unit)
        meal_in_threshold = _convert_unit(meal_amount, nutrient_unit, threshold_unit)
        projected_in_threshold = consumed_today_in_threshold + meal_in_threshold
        ratio = (projected_in_threshold / threshold_amount) if threshold_amount > 0 else 0.0

        evaluations.append(
            ConditionEvaluation(
                condition_name=condition_name,
                restricted_nutrient=restricted_nutrient,
                threshold_amount=threshold_amount,
                threshold_unit=threshold_unit,
                consumed_today_amount=consumed_today_in_threshold,
                meal_amount=meal_in_threshold,
                projected_amount=projected_in_threshold,
                consumed_amount=projected_in_threshold,
                consumed_unit=threshold_unit,
                exceeds_limit=projected_in_threshold > threshold_amount,
                is_close_to_limit=(projected_in_threshold <= threshold_amount) and ratio >= 0.8,
            )
        )

    return evaluations


def _build_profile_message(
    status: str,
    calorie_eval: CalorieEvaluation,
    condition_evaluations: list[ConditionEvaluation],
) -> str:
    exceeded_conditions = [
        f"{c.condition_name} ({c.restricted_nutrient})"
        for c in condition_evaluations
        if c.exceeds_limit
    ]
    close_conditions = [
        f"{c.condition_name} ({c.restricted_nutrient})"
        for c in condition_evaluations
        if c.is_close_to_limit
    ]

    if status == "warning":
        if exceeded_conditions:
            return (
                "Based on your profile, adding this meal would exceed your daily limits for "
                + ", ".join(exceeded_conditions)
                + "."
            )
        if calorie_eval.daily_goal is not None and calorie_eval.exceeds_limit:
            return "Based on your profile calorie goal, this meal would push you over today's calorie limit."
        return "Based on your profile, this meal would exceed one or more health limits."

    if status == "caution":
        if close_conditions:
            return (
                "Based on your profile, this meal keeps you close to your daily limits for "
                + ", ".join(close_conditions)
                + "."
            )
        if calorie_eval.daily_goal is not None and calorie_eval.projected_total >= 0.8 * calorie_eval.daily_goal:
            return "Based on your profile calorie goal, this meal brings you close to today's limit."
        return _status_message(status)

    return "Based on your profile, this meal fits your current daily nutrition targets."

@router.post("/", response_model=HealthConditionResponse, status_code=status.HTTP_201_CREATED)
async def add_condition(payload: HealthConditionCreate, _admin: dict = Depends(get_current_admin)):
    supabase = get_supabase_admin()
    result = supabase.table("health_conditions").insert(payload.model_dump()).execute()
    if not result.data:
        raise HTTPException(status_code=400, detail="Failed to create condition")
    return result.data[0]

@router.get("/", response_model=List[HealthConditionResponse])
async def get_conditions():
    """Get all health conditions (public endpoint)"""
    supabase = get_supabase_admin()
    result = supabase.table("health_conditions").select("*").execute()
    return result.data


@router.post("/evaluate-food", response_model=FoodHealthEvaluationResponse)
async def evaluate_food_against_health_rules(
    payload: FoodHealthEvaluationRequest,
    current_user: dict = Depends(get_current_user),
):
    """Evaluate incoming nutrients against user condition limits and daily calories."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    evaluated_at = payload.consumed_at or datetime.now(timezone.utc)
    day = evaluated_at.date()
    consumed_today = _fetch_daily_nutrients(supabase, user_id, day)
    incoming_meal = DailyNutrientTotals(
        calories=float(payload.nutrients.calories),
        sugar_g=float(payload.nutrients.sugar_g),
        sodium_mg=float(payload.nutrients.sodium_mg),
        cholesterol_mg=float(payload.nutrients.cholesterol_mg),
        fat_g=float(payload.nutrients.fat_g),
    )

    daily_goal = _resolve_daily_calorie_goal(current_user)
    meal_calories = float(payload.nutrients.calories)
    projected_total = consumed_today.calories + meal_calories

    calorie_exceeds = (projected_total > daily_goal) if daily_goal is not None else None
    calorie_eval = CalorieEvaluation(
        daily_goal=daily_goal,
        consumed_today=consumed_today.calories,
        meal_calories=meal_calories,
        projected_total=projected_total,
        exceeds_limit=calorie_exceeds,
    )

    conditions = _fetch_user_conditions(supabase, user_id)
    condition_evaluations = _evaluate_conditions(consumed_today, incoming_meal, conditions)

    has_warning = bool(calorie_eval.exceeds_limit) or any(c.exceeds_limit for c in condition_evaluations)
    has_caution = (
        any(c.is_close_to_limit for c in condition_evaluations)
        or (
            daily_goal is not None
            and not bool(calorie_eval.exceeds_limit)
            and calorie_eval.projected_total >= 0.8 * daily_goal
        )
    )
    status_value = "warning" if has_warning else ("caution" if has_caution else "good")

    return FoodHealthEvaluationResponse(
        status=status_value,
        message=_build_profile_message(status_value, calorie_eval, condition_evaluations),
        evaluated_at=evaluated_at,
        calorie=calorie_eval,
        conditions=condition_evaluations,
    )


@router.get("/daily-summary", response_model=DailyHealthSummaryResponse)
async def get_daily_health_summary(
    date_str: str | None = Query(default=None, alias="date"),
    current_user: dict = Depends(get_current_user),
):
    """Return consumed nutrients and condition limit status for a specific day."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    day = _parse_day_or_today(date_str)

    consumed_today = _fetch_daily_nutrients(supabase, user_id, day)
    conditions = _fetch_user_conditions(supabase, user_id)
    zero_meal = DailyNutrientTotals()
    condition_evaluations = _evaluate_conditions(consumed_today, zero_meal, conditions)

    statuses = [
        DailyConditionStatus(
            condition_name=c.condition_name,
            restricted_nutrient=c.restricted_nutrient,
            threshold_amount=c.threshold_amount,
            threshold_unit=c.threshold_unit,
            consumed_amount=c.projected_amount,
            remaining_amount=max(c.threshold_amount - c.projected_amount, 0),
            exceeds_limit=c.exceeds_limit,
        )
        for c in condition_evaluations
    ]

    return DailyHealthSummaryResponse(
        date=day.isoformat(),
        daily_calorie_goal=_resolve_daily_calorie_goal(current_user),
        nutrients_consumed=consumed_today,
        condition_statuses=statuses,
    )


@router.get("/history", response_model=HealthHistoryResponse)
async def get_health_history(
    from_date: str | None = Query(default=None),
    to_date: str | None = Query(default=None),
    days: int = Query(default=14, ge=1, le=90),
    current_user: dict = Depends(get_current_user),
):
    """Return day-level history with calorie and condition-limit adherence status."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    end_day = _parse_day_or_today(to_date)
    if from_date:
        start_day = _parse_day_or_today(from_date)
    else:
        start_day = end_day - timedelta(days=days - 1)

    if start_day > end_day:
        raise HTTPException(status_code=400, detail="from_date must be before or equal to to_date")

    all_days: list[HistoryDaySummary] = []
    conditions = _fetch_user_conditions(supabase, user_id)
    daily_goal = _resolve_daily_calorie_goal(current_user)
    cursor = start_day

    while cursor <= end_day:
        consumed = _fetch_daily_nutrients(supabase, user_id, cursor)
        condition_eval = _evaluate_conditions(consumed, DailyNutrientTotals(), conditions)

        calorie_exceeded = (consumed.calories > daily_goal) if daily_goal is not None else None
        has_warning = bool(calorie_exceeded) or any(c.exceeds_limit for c in condition_eval)
        has_caution = (
            any(c.is_close_to_limit for c in condition_eval)
            or (
                daily_goal is not None
                and not bool(calorie_exceeded)
                and consumed.calories >= 0.8 * daily_goal
            )
        )
        status_value = "warning" if has_warning else ("caution" if has_caution else "good")

        alerts: list[str] = []
        for c in condition_eval:
            if c.exceeds_limit:
                alerts.append(f"{c.condition_name}: {c.restricted_nutrient} exceeded")
            elif c.is_close_to_limit:
                alerts.append(f"{c.condition_name}: {c.restricted_nutrient} close to limit")

        all_days.append(
            HistoryDaySummary(
                date=cursor.isoformat(),
                status=status_value,
                daily_calorie_goal=daily_goal,
                calories_consumed=consumed.calories,
                calorie_limit_exceeded=calorie_exceeded,
                condition_alerts=alerts,
            )
        )
        cursor += timedelta(days=1)

    return HealthHistoryResponse(
        from_date=start_day.isoformat(),
        to_date=end_day.isoformat(),
        days=all_days,
    )


@router.get("/{condition_id}", response_model=HealthConditionResponse)
async def get_condition(condition_id: UUID, _user: dict = Depends(get_current_user)):
    supabase = get_supabase_admin()
    result = supabase.table("health_conditions").select("*").eq("id", str(condition_id)).maybe_single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Condition not found")
    return result.data


@router.put("/{condition_id}", response_model=HealthConditionResponse)
async def update_condition(condition_id: UUID, payload: HealthConditionUpdate, _admin: dict = Depends(get_current_admin)):
    supabase = get_supabase_admin()
    update_data = payload.model_dump(exclude_unset=True)
    result = supabase.table("health_conditions").update(update_data).eq("id", str(condition_id)).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Condition not found")
    return result.data[0]


@router.delete("/{condition_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_condition(condition_id: UUID, _admin: dict = Depends(get_current_admin)):
    supabase = get_supabase_admin()
    supabase.table("health_conditions").delete().eq("id", str(condition_id)).execute()
    return None