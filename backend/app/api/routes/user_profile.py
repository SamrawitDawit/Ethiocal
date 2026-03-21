from fastapi import APIRouter, Depends, HTTPException, status
from app.db.supabase import get_supabase_admin
from app.core.dependencies import get_current_user, get_current_auth_user
from app.schemas.user_profile import UserProfileUpdate, UserProfileResponse

router = APIRouter()

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user: dict = Depends(get_current_user)):
    """Get the profile of the currently authenticated user, including health conditions."""
    supabase = get_supabase_admin()
    user_id = current_user["user_id"] # Get the user_id (FK) from the profile row
    
    # Fetch profile with health conditions through the junction table
    result = supabase.table("user_profile")\
        .select("*, health_conditions:profile_health_conditions(condition:health_conditions(*))")\
        .eq("user_id", user_id)\
        .single()\
        .execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Flatten the nested structure from the join
    data = result.data
    data["health_conditions"] = [item["condition"] for item in data.get("health_conditions", [])]
    
    return data

@router.post("/", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_my_profile(
    payload: UserProfileUpdate, 
    auth_user: dict = Depends(get_current_auth_user)
):
    """Create a new profile for the authenticated user."""
    supabase = get_supabase_admin()
    user_id = auth_user["id"]

    # 1. Insert the profile data
    profile_data = payload.model_dump(exclude={"health_condition_ids"}, exclude_unset=True)
    profile_data["user_id"] = user_id

    result = supabase.table("user_profile").insert(profile_data).execute()
    
    if not result.data:
        raise HTTPException(status_code=400, detail="Failed to create profile")
    
    new_profile = result.data[0]
    profile_id = new_profile["id"]

    # 2. Insert health conditions if provided
    if payload.health_condition_ids:
        relations = [
            {"profile_id": profile_id, "condition_id": str(cid)}
            for cid in payload.health_condition_ids
        ]
        supabase.table("profile_health_conditions").insert(relations).execute()

    # 3. Return the full profile structure using the GET logic
    # We construct a temporary user dict to reuse the existing dependency logic or just call the function if feasible, 
    # but fetching fresh is safer to ensure formatting matches UserProfileResponse.
    # We can reuse the get_my_profile logic by mocking the dependency return:
    return await get_my_profile(current_user={"user_id": user_id})

@router.put("/me", response_model=UserProfileResponse)
async def update_my_profile(payload: UserProfileUpdate, current_user: dict = Depends(get_current_user)):
    """Update profile details and health condition associations."""
    supabase = get_supabase_admin()
    user_id = current_user["user_id"]
    profile_id = current_user["id"] # This is the profileId (PK)
    
    update_dict = payload.model_dump(exclude={"health_condition_ids"}, exclude_unset=True)
    
    if update_dict:
        supabase.table("user_profile").update(update_dict).eq("user_id", user_id).execute()

    # Handle health condition relationships if provided
    if payload.health_condition_ids is not None:
        # Clear existing relations
        supabase.table("profile_health_conditions").delete().eq("profile_id", profile_id).execute()
        
        # Insert new relations
        if payload.health_condition_ids:
            new_relations = [
                {"profile_id": profile_id, "condition_id": str(cid)} 
                for cid in payload.health_condition_ids
            ]
            supabase.table("profile_health_conditions").insert(new_relations).execute()

    return await get_my_profile(current_user)

@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_profile(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's profile."""
    supabase = get_supabase_admin()
    user_id = current_user["user_id"]
    
    supabase.table("user_profile").delete().eq("user_id", user_id).execute()
    
    return None
