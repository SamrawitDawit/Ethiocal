# ============================================
# EthioCal — User Profile Routes
# ============================================
# GET   /me               — get current user profile
# POST  /setup-profile    — complete profile setup
# PATCH /me               — update basic profile info
# PATCH /profile          — update extended profile data
# GET   /health-conditions— list available health conditions
# POST  /health-conditions— add health condition to user
# DELETE /health-conditions/{id} — remove health condition
# ============================================

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_current_user, get_current_admin
from app.db.supabase import get_supabase_admin
from app.schemas.user import (
    UserResponse,
    UserBasicResponse,
    UserProfileSetup,
    UserProfileUpdate,
    UserProfileDataUpdate,
    HealthConditionResponse,
    HealthConditionCreate,
    UserHealthConditionAdd,
)

router = APIRouter()


@router.get("/me", response_model=UserBasicResponse)
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Return the authenticated user's basic profile."""
    return current_user


@router.post("/setup-profile", response_model=UserBasicResponse)
async def setup_profile(
    payload: UserProfileSetup,
    current_user: dict = Depends(get_current_user),
):
    """Complete profile setup after registration.

    Updates the profiles record with extended info (age, weight, etc.).
    """
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Update the profiles table with extended profile data
    profile_data = {
        "age": payload.age,
        "gender": payload.gender,
        "height": payload.height,
        "weight": payload.weight,
        "activity_level": payload.activity_level,
        "daily_calorie_goal": payload.daily_calorie_goal,
    }

    result = (
        supabase.table("profiles")
        .update(profile_data)
        .eq("id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profile update failed.",
        )

    # Handle health conditions
    if payload.health_condition_ids:
        # Remove existing health conditions
        supabase.table("user_health_conditions").delete().eq("user_id", user_id).execute()

        # Add new health conditions
        for condition_id in payload.health_condition_ids:
            supabase.table("user_health_conditions").insert({
                "user_id": user_id,
                "health_condition_id": condition_id,
            }).execute()

    return result.data[0]


@router.patch("/me", response_model=UserBasicResponse)
async def update_profile(
    payload: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update the authenticated user's basic profile fields."""
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update.",
        )

    supabase = get_supabase_admin()
    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", current_user["id"])
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profile update failed.",
        )

    return result.data[0]


@router.patch("/profile", response_model=UserBasicResponse)
async def update_profile_data(
    payload: UserProfileDataUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update the user's extended profile data (age, weight, etc.)."""
    update_data = payload.model_dump(exclude_unset=True)

    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update.",
        )

    supabase = get_supabase_admin()
    result = (
        supabase.table("profiles")
        .update(update_data)
        .eq("id", current_user["id"])
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Profile update failed.",
        )

    return result.data[0]


@router.get("/health-conditions", response_model=list[HealthConditionResponse])
async def list_health_conditions(current_user: dict = Depends(get_current_user)):
    """List all available health conditions."""
    supabase = get_supabase_admin()
    result = supabase.table("health_conditions").select("*").order("condition_name").execute()
    return result.data


@router.post("/health-conditions")
async def add_health_condition(
    payload: UserHealthConditionAdd,
    current_user: dict = Depends(get_current_user),
):
    """Add a health condition to the current user."""
    supabase = get_supabase_admin()

    # Check if condition exists
    condition = (
        supabase.table("health_conditions")
        .select("id")
        .eq("id", payload.health_condition_id)
        .maybe_single()
        .execute()
    )

    if not condition.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health condition not found.",
        )

    # Add to user
    try:
        supabase.table("user_health_conditions").insert({
            "user_id": current_user["id"],
            "health_condition_id": payload.health_condition_id,
        }).execute()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Health condition already added.",
        )

    return {"message": "Health condition added successfully."}


@router.delete("/health-conditions/{condition_id}")
async def remove_health_condition(
    condition_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Remove a health condition from the current user."""
    supabase = get_supabase_admin()

    result = (
        supabase.table("user_health_conditions")
        .delete()
        .eq("user_id", current_user["id"])
        .eq("health_condition_id", condition_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health condition not found for this user.",
        )

    return {"message": "Health condition removed successfully."}


# --- Admin endpoints for managing health conditions ---

@router.post("/admin/health-conditions", response_model=HealthConditionResponse)
async def create_health_condition(
    payload: HealthConditionCreate,
    current_admin: dict = Depends(get_current_admin),
):
    """Create a new health condition (admin only)."""
    supabase = get_supabase_admin()

    try:
        result = supabase.table("health_conditions").insert({
            "condition_name": payload.condition_name,
            "restricted_nutrient": payload.restricted_nutrient,
            "threshold_amount": payload.threshold_amount,
            "threshold_unit": payload.threshold_unit,
        }).execute()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Health condition with this name already exists.",
        )

    return result.data[0]


@router.delete("/admin/health-conditions/{condition_id}")
async def delete_health_condition(
    condition_id: str,
    current_admin: dict = Depends(get_current_admin),
):
    """Delete a health condition (admin only)."""
    supabase = get_supabase_admin()

    result = (
        supabase.table("health_conditions")
        .delete()
        .eq("id", condition_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Health condition not found.",
        )

    return {"message": "Health condition deleted successfully."}
