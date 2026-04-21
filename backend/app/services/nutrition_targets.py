from __future__ import annotations

from datetime import date, datetime
from typing import Any


DISCLAIMER = (
    "These are general dietary targets based on 2026 ADA/AHA/Ethiopian NCD guidelines to support clinical goals "
    "(HbA1c <7.0%, BP <130/80, LDL <100 mg/dL or lower). They are not medical advice. Always consult your doctor."
)


def _get_condition_based_nutrient_targets(profile: dict, calorie_goal: float) -> dict:
    has_diabetes = bool(profile.get("has_diabetes"))
    has_hypertension = bool(profile.get("has_hypertension"))
    has_high_cholesterol = bool(profile.get("has_high_cholesterol"))
    diabetes_type = profile.get("diabetes_type")
    latest_hba1c = profile.get("latest_hba1c")

    saturated_percent = 0.05 if has_high_cholesterol else 0.07
    saturated_fat_g = round((calorie_goal * saturated_percent) / 9.0, 1)
    fiber_g = 30.0
    sodium_mg = 1500.0 if has_hypertension else 2300.0
    carbs_percent = 45.0 if latest_hba1c is not None and float(latest_hba1c) > 7.5 else 50.0
    daily_carbs_g = round((calorie_goal * carbs_percent / 100.0) / 4.0, 1)
    carbs_g_per_meal = round(daily_carbs_g / 3.0, 1) if has_diabetes else None

    note = None
    if has_diabetes and diabetes_type == "Type 1":
        note = "Type 1 diabetes: keep per-meal carbohydrates especially consistent and coordinate insulin dosing with your clinician."
    elif has_diabetes:
        note = "Diabetes: distribute carbohydrates consistently across meals."

    return {
        "saturated_fat_g": saturated_fat_g,
        "fiber_g": fiber_g,
        "sodium_mg": sodium_mg,
        "carbs_percent": carbs_percent,
        "daily_carbs_g": daily_carbs_g,
        "carbs_g_per_meal": carbs_g_per_meal,
        "note": note,
    }


def _check_meal_against_targets(
    profile: dict,
    calorie_goal: float,
    meal_nutrients: dict,
    current_daily_totals: dict,
) -> list[str]:
    targets = _get_condition_based_nutrient_targets(profile, calorie_goal)
    warnings: list[str] = []

    projected_saturated_fat = float(current_daily_totals.get("saturated_fat_g", 0.0)) + float(meal_nutrients.get("saturated_fat_g", 0.0))
    projected_sodium = float(current_daily_totals.get("sodium_mg", 0.0)) + float(meal_nutrients.get("sodium_mg", 0.0))

    if projected_saturated_fat > targets["saturated_fat_g"]:
        warnings.append("Projected saturated fat exceeds today's target.")

    if projected_sodium > targets["sodium_mg"]:
        warnings.append("Projected sodium exceeds today's target.")

    if profile.get("has_diabetes") and targets.get("carbs_g_per_meal"):
        meal_carbs = float(meal_nutrients.get("carbs_g", 0.0))
        if meal_carbs > float(targets["carbs_g_per_meal"]) * 1.2:
            warnings.append("This meal is high in carbs for a single sitting.")

    if float(meal_nutrients.get("fiber_g", 0.0)) < 5.0:
        warnings.append("Very low fiber in this meal.")

    return warnings


def _combine_totals(current_daily_totals: dict, meal_nutrients: dict) -> dict:
    return {
        "calories": float(current_daily_totals.get("calories", 0.0)) + float(meal_nutrients.get("calories", 0.0)),
        "carbs_g": float(current_daily_totals.get("carbs_g", 0.0)) + float(meal_nutrients.get("carbs_g", 0.0)),
        "saturated_fat_g": float(current_daily_totals.get("saturated_fat_g", 0.0)) + float(meal_nutrients.get("saturated_fat_g", 0.0)),
        "sodium_mg": float(current_daily_totals.get("sodium_mg", 0.0)) + float(meal_nutrients.get("sodium_mg", 0.0)),
        "fiber_g": float(current_daily_totals.get("fiber_g", 0.0)) + float(meal_nutrients.get("fiber_g", 0.0)),
        "protein_g": float(current_daily_totals.get("protein_g", 0.0)) + float(meal_nutrients.get("protein_g", 0.0)),
    }


def _build_progress(projected_daily_totals: dict, targets: dict, calorie_goal: float) -> dict:
    daily_carbs_target = targets.get("daily_carbs_g") or 0.0
    return {
        "calories_percent": round((float(projected_daily_totals.get("calories", 0.0)) / calorie_goal) * 100.0, 1) if calorie_goal else 0.0,
        "saturated_fat_percent": round((float(projected_daily_totals.get("saturated_fat_g", 0.0)) / float(targets["saturated_fat_g"])) * 100.0, 1) if targets.get("saturated_fat_g") else 0.0,
        "sodium_percent": round((float(projected_daily_totals.get("sodium_mg", 0.0)) / float(targets["sodium_mg"])) * 100.0, 1) if targets.get("sodium_mg") else 0.0,
        "fiber_percent": round((float(projected_daily_totals.get("fiber_g", 0.0)) / float(targets["fiber_g"])) * 100.0, 1) if targets.get("fiber_g") else 0.0,
        "carbs_percent": round((float(projected_daily_totals.get("carbs_g", 0.0)) / daily_carbs_target) * 100.0, 1) if daily_carbs_target else 0.0,
    }


async def calculate_current_daily_totals(supabase: Any, user_id: str, meal_date: date | None = None) -> dict:
    query_date = meal_date or date.today()
    start_datetime = datetime.combine(query_date, datetime.min.time())
    end_datetime = datetime.combine(query_date, datetime.max.time())

    meals_result = (
        supabase.table("meals")
        .select("id, image_url")
        .eq("user_id", user_id)
        .gte("created_at", start_datetime.isoformat())
        .lte("created_at", end_datetime.isoformat())
        .execute()
    )

    totals = {
        "calories": 0.0,
        "carbs_g": 0.0,
        "saturated_fat_g": 0.0,
        "sodium_mg": 0.0,
        "fiber_g": 0.0,
        "protein_g": 0.0,
    }

    meals = meals_result.data or []
    if not meals:
        return totals

    meal_map = {meal["id"]: meal for meal in meals}
    meal_ids = list(meal_map.keys())

    meal_food_items_result = (
        supabase.table("meal_food_items")
        .select("meal_id, quantity, food_item:food_items(*)")
        .in_("meal_id", meal_ids)
        .execute()
    )

    for item in meal_food_items_result.data or []:
        food_item = item.get("food_item") or {}
        meal = meal_map.get(item.get("meal_id"), {})
        quantity = float(item.get("quantity") or 0.0)
        if meal.get("image_url"):
            scale = quantity / 100.0
        else:
            scale = quantity * float(food_item.get("standard_serving_size", 100.0)) / 100.0

        totals["calories"] += scale * float(food_item.get("calories_per_100g", 0.0))
        totals["carbs_g"] += scale * float(food_item.get("carbohydrates", 0.0))
        totals["saturated_fat_g"] += scale * float(food_item.get("saturated_fat_g", 0.0))
        totals["sodium_mg"] += scale * float(food_item.get("sodium_mg", 0.0))
        totals["fiber_g"] += scale * float(food_item.get("fiber", 0.0))
        totals["protein_g"] += scale * float(food_item.get("protein", 0.0))

    meal_ingredients_result = (
        supabase.table("meal_ingredients")
        .select("quantity, ingredient:ingredients(*)")
        .in_("meal_id", meal_ids)
        .execute()
    )

    for item in meal_ingredients_result.data or []:
        ingredient = item.get("ingredient") or {}
        quantity = float(item.get("quantity") or 0.0)
        scale = quantity / 100.0
        totals["calories"] += scale * float(ingredient.get("calories_per_100g", 0.0))
        totals["carbs_g"] += scale * float(ingredient.get("carbohydrates", 0.0))
        totals["saturated_fat_g"] += scale * float(ingredient.get("saturated_fat_g", 0.0))
        totals["sodium_mg"] += scale * float(ingredient.get("sodium_mg", 0.0))
        totals["fiber_g"] += scale * float(ingredient.get("fiber", 0.0))
        totals["protein_g"] += scale * float(ingredient.get("protein", 0.0))

    return totals
