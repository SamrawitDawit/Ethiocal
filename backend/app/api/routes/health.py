from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from uuid import UUID
from app.db.supabase import get_supabase_admin
from app.schemas.health import HealthConditionCreate, HealthConditionUpdate, HealthConditionResponse
from app.core.dependencies import get_current_user, get_current_admin

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