from fastapi import APIRouter, Depends, HTTPException, status
from app.db.supabase import get_supabase_admin
from app.core.dependencies import get_current_user
from app.schemas.user_profile import UserProfileUpdate, UserProfileResponse

router = APIRouter()


def _load_health_conditions_for_user(supabase, user_id: str) -> list[dict]:
    result = (
        supabase.table("user_health_conditions")
        .select("health_conditions(*)")
        .eq("user_id", user_id)
        .execute()
    )
    return [
        row["health_conditions"]
        for row in (result.data or [])
        if row.get("health_conditions")
    ]

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: dict = Depends(get_current_user)):
    """Get the authenticated user's profile plus selected health conditions."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    result = (
        supabase.table("profiles")
        .select("*")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    data = result.data
    data["user_id"] = data["id"]
    data["health_conditions"] = _load_health_conditions_for_user(supabase, user_id)

    return data

@router.post("/", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_my_profile(
    payload: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Complete profile setup (upsert-like behavior) for the authenticated user."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]

    profile_data = payload.model_dump(exclude={"health_condition_ids"}, exclude_unset=True)
    if profile_data:
        update_result = (
            supabase.table("profiles")
            .update(profile_data)
            .eq("id", user_id)
            .execute()
        )
        if not update_result.data:
            raise HTTPException(status_code=400, detail="Failed to update profile")

    if payload.health_condition_ids is not None:
        supabase.table("user_health_conditions").delete().eq("user_id", user_id).execute()
        if payload.health_condition_ids:
            relations = [
                {"user_id": user_id, "health_condition_id": str(cid)}
                for cid in payload.health_condition_ids
            ]
            supabase.table("user_health_conditions").insert(relations).execute()

    return await get_my_profile(current_user)

@router.put("/me", response_model=UserProfileResponse)
async def update_my_profile(payload: UserProfileUpdate, current_user: dict = Depends(get_current_user)):
    """Update profile details and health condition associations."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    update_dict = payload.model_dump(exclude={"health_condition_ids"}, exclude_unset=True)
    
    if update_dict:
        supabase.table("profiles").update(update_dict).eq("id", user_id).execute()

    # Handle health condition relationships if provided
    if payload.health_condition_ids is not None:
        # Clear existing relations
        supabase.table("user_health_conditions").delete().eq("user_id", user_id).execute()
        
        # Insert new relations
        if payload.health_condition_ids:
            new_relations = [
                {"user_id": user_id, "health_condition_id": str(cid)} 
                for cid in payload.health_condition_ids
            ]
            supabase.table("user_health_conditions").insert(new_relations).execute()

    return await get_my_profile(current_user)

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_profile(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's profile."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    supabase.table("profiles").delete().eq("id", user_id).execute()
    
    return None
