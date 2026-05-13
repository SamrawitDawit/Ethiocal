from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from app.db.supabase import get_supabase_admin
from app.core.dependencies import get_current_user, get_current_auth_user
from app.schemas.user_profile import UserProfileUpdate, UserProfileResponse
from app.services.user_health_conditions import (
    get_user_profile_with_health,
    save_user_health_conditions,
    split_profile_and_health_updates,
)

router = APIRouter()

def calculate_age(birthdate: date) -> int:
    """Helper to calculate age from birthdate."""
    today = date.today()
    return today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: dict = Depends(get_current_user)):
    """Get the profile of the currently authenticated user, including health conditions."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    data = get_user_profile_with_health(supabase, user_id)

    if not data:
        raise HTTPException(status_code=404, detail="Profile not found")

    # Priority: calculate age from birthdate if available
    if data.get("birthdate"):
        data["age"] = calculate_age(date.fromisoformat(data["birthdate"]))
    
    return data

@router.post("/", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_my_profile(
    payload: UserProfileUpdate, 
    auth_user: dict = Depends(get_current_auth_user)
):
    """Create a new profile for the authenticated user."""
    # Note: In the new schema, profiles are auto-created on signup. 
    # This POST effectively acts as an update for those initial fields.
    supabase = get_supabase_admin()
    user_id = auth_user["id"]

    # 1. Update the profile data (since row already exists via trigger)
    payload_data = payload.model_dump(
        mode='json',
        exclude={"health_condition_ids"},
        exclude_unset=True,
    )
    profile_data, health_updates = split_profile_and_health_updates(payload_data)

    if profile_data:
        result = supabase.table("profiles").update(profile_data).eq("id", user_id).execute()
        if not result.data:
            raise HTTPException(status_code=400, detail="Failed to setup profile")
    else:
        existing_profile = get_user_profile_with_health(supabase, user_id)
        if not existing_profile:
            raise HTTPException(status_code=404, detail="Profile not found")
    
    # 2. Persist health conditions and metadata in the junction table
    if payload.health_condition_ids is not None or health_updates:
        save_user_health_conditions(
            supabase,
            user_id,
            health_updates=health_updates,
            health_condition_ids=payload.health_condition_ids,
        )

    # 3. Return the newly created profile with health conditions
    return await get_my_profile(current_user=result.data[0])

@router.put("/me", response_model=UserProfileResponse)
async def update_my_profile(payload: UserProfileUpdate, current_user: dict = Depends(get_current_user)):
    """Update profile details and health condition associations."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    update_dict = payload.model_dump(mode='json', exclude={"health_condition_ids"}, exclude_unset=True)
    profile_data, health_updates = split_profile_and_health_updates(update_dict)
    
    if profile_data:
        supabase.table("profiles").update(profile_data).eq("id", user_id).execute()

    # Handle health condition relationships if provided
    if payload.health_condition_ids is not None or health_updates:
        save_user_health_conditions(
            supabase,
            user_id,
            health_updates=health_updates,
            health_condition_ids=payload.health_condition_ids,
        )

    return await get_my_profile(current_user)

@router.patch("/me", response_model=UserProfileResponse)
async def patch_my_profile(payload: UserProfileUpdate, current_user: dict = Depends(get_current_user)):
    """Partial update of profile details and health condition associations."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    # extract only fields that were actually sent in the request
    update_dict = payload.model_dump(mode='json', exclude={"health_condition_ids"}, exclude_unset=True)
    profile_data, health_updates = split_profile_and_health_updates(update_dict)
    
    if profile_data:
        result = supabase.table("profiles").update(profile_data).eq("id", user_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="Profile not found")

    # Handle health condition relationships if the key was present in the request
    if payload.health_condition_ids is not None or health_updates:
        save_user_health_conditions(
            supabase,
            user_id,
            health_updates=health_updates,
            health_condition_ids=payload.health_condition_ids,
        )

    return await get_my_profile(current_user)

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_profile(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's profile."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    supabase.table("profiles").delete().eq("id", user_id).execute()
    
    return None
