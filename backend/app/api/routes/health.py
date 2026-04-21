from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from uuid import UUID
from app.db.supabase import get_supabase_admin
from app.schemas.health import (
    HealthConditionCreate,
    HealthConditionUpdate,
    HealthConditionResponse,
    MealTargetCheckRequest,
    MealTargetCheckResponse,
)
from app.core.dependencies import get_current_user, get_current_admin
from app.services.nutrition_targets import (
    DISCLAIMER,
    _build_progress,
    _check_meal_against_targets,
    _combine_totals,
    _get_condition_based_nutrient_targets,
    calculate_current_daily_totals,
)

router = APIRouter()

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


@router.post("/meal-check", response_model=MealTargetCheckResponse)
async def check_meal_against_health_targets(
    payload: MealTargetCheckRequest,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    profile_result = (
        supabase.table("profiles")
        .select("daily_calorie_goal, has_diabetes, has_hypertension, has_high_cholesterol, diabetes_type, latest_hba1c")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )

    profile_rows = profile_result.data or []
    profile = profile_rows[0] if profile_rows else {}
    calorie_goal = float(profile.get("daily_calorie_goal") or 2000.0)
    current_daily_totals = await calculate_current_daily_totals(supabase, user_id, date.today())
    meal_nutrients = payload.meal_nutrients.model_dump()

    targets = _get_condition_based_nutrient_targets(profile, calorie_goal)
    warnings = _check_meal_against_targets(profile, calorie_goal, meal_nutrients, current_daily_totals)
    projected_daily_totals = _combine_totals(current_daily_totals, meal_nutrients)
    progress = _build_progress(projected_daily_totals, targets, calorie_goal)

    return MealTargetCheckResponse(
        warnings=warnings,
        disclaimer=DISCLAIMER,
        note=targets.get("note"),
        targets=targets,
        current_daily_totals=current_daily_totals,
        projected_daily_totals=projected_daily_totals,
        progress=progress,
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