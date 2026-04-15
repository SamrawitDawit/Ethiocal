# ============================================
# EthioCal - Daily Summary Routes
# ============================================
# GET  /?date=YYYY-MM-DD  - get daily summary for specific date
# POST /                  - create/update daily summary
# ============================================

from fastapi import APIRouter, Depends, HTTPException, Query, status
from datetime import datetime, date
from typing import Optional

from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.daily_summary import (
    DailySummaryCreate,
    DailySummaryResponse,
    DailySummaryDashboard,
    DailySummaryUpdate
)

router = APIRouter()

@router.get("/", response_model=DailySummaryDashboard)
async def get_daily_summary(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    """Get optimized daily summary for dashboard - single call replacing 4 separate calls."""
    try:
        print(f"\n=== get_daily_summary called ===")
        print(f"Date: {date}")
        print(f"User: {current_user.get('id')}")
        
        supabase = get_supabase_admin()
        user_id = current_user["id"]
        
        # Parse date
        query_date = datetime.strptime(date, '%Y-%m-%d').date()
        
        # First, try to get existing daily summary
        existing_summary = (
            supabase.table("daily_summaries")
            .select("*")
            .eq("user_id", user_id)
            .eq("date", query_date.isoformat())
            .maybe_single()
            .execute()
        )
        
        if existing_summary and existing_summary.data:
            print(f"Found existing summary: {existing_summary.data}")
            
            # Build meal breakdown from stored values
            meal_breakdown = {
                'breakfast': {'calories': existing_summary.data['breakfast_calories'], 'count': 1 if existing_summary.data['breakfast_calories'] > 0 else 0},
                'lunch': {'calories': existing_summary.data['lunch_calories'], 'count': 1 if existing_summary.data['lunch_calories'] > 0 else 0},
                'dinner': {'calories': existing_summary.data['dinner_calories'], 'count': 1 if existing_summary.data['dinner_calories'] > 0 else 0},
                'snack': {'calories': existing_summary.data['snack_calories'], 'count': 1 if existing_summary.data['snack_calories'] > 0 else 0},
            }
            
            return DailySummaryDashboard(
                date=existing_summary.data['date'],
                total_calories=existing_summary.data['total_calories'],
                total_protein=existing_summary.data['total_protein'],
                total_carbohydrates=existing_summary.data['total_carbohydrates'],
                total_fat=existing_summary.data['total_fat'],
                breakfast_calories=existing_summary.data['breakfast_calories'],
                lunch_calories=existing_summary.data['lunch_calories'],
                dinner_calories=existing_summary.data['dinner_calories'],
                snack_calories=existing_summary.data['snack_calories'],
                meal_count=existing_summary.data['meal_count'],
                daily_calorie_goal=existing_summary.data['daily_calorie_goal'],
                meal_breakdown=meal_breakdown,
                success=True
            )
        
        # If no existing summary, calculate and store it
        print("No existing summary found, calculating from scratch...")
        
        # Get user's daily calorie goal
        profile_result = (
            supabase.table("profiles")
            .select("daily_calorie_goal")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        daily_calorie_goal = profile_result.data.get("daily_calorie_goal", 2000) if profile_result.data else 2000
        
        # Calculate date range for meals
        start_datetime = datetime.combine(query_date, datetime.min.time())
        end_datetime = datetime.combine(query_date, datetime.max.time())
        
        # Get meals for the date
        meals_result = (
            supabase.table("meals")
            .select("id, meal_type, total_calories")
            .eq("user_id", user_id)
            .gte("created_at", start_datetime.isoformat())
            .lte("created_at", end_datetime.isoformat())
            .execute()
        )
        
        # Initialize totals
        total_calories = 0
        total_protein = 0.0
        total_carbohydrates = 0.0
        total_fat = 0.0
        breakfast_calories = 0
        lunch_calories = 0
        dinner_calories = 0
        snack_calories = 0
        meal_count = len(meals_result.data) if meals_result.data else 0
        
        # Calculate meal type breakdown
        if meals_result.data:
            for meal in meals_result.data:
                meal_type = meal['meal_type']
                calories = meal.get('total_calories', 0)
                total_calories += calories
                
                if meal_type == 'breakfast':
                    breakfast_calories += calories
                elif meal_type == 'lunch':
                    lunch_calories += calories
                elif meal_type == 'dinner':
                    dinner_calories += calories
                elif meal_type == 'snack':
                    snack_calories += calories
            
            # Get meal IDs for nutrient calculation
            meal_ids = [meal["id"] for meal in meals_result.data]
            
            # Get food items for nutrient calculation
            food_items_result = (
                supabase.table("meal_food_items")
                .select("""
                    quantity,
                    food_item:food_items (
                        protein,
                        carbohydrates,
                        fat
                    )
                """)
                .in_("meal_id", meal_ids)
                .execute()
            )
            
            # Calculate nutrient totals
            for item in (food_items_result.data or []):
                quantity = item.get("quantity", 1)
                food_item = item.get("food_item")
                
                if food_item:
                    serving_multiplier = quantity
                    total_protein += (food_item.get("protein", 0) * serving_multiplier)
                    total_carbohydrates += (food_item.get("carbohydrates", 0) * serving_multiplier)
                    total_fat += (food_item.get("fat", 0) * serving_multiplier)
        
        # Create new daily summary
        new_summary = {
            "user_id": user_id,
            "date": query_date.isoformat(),
            "total_calories": total_calories,
            "total_protein": round(total_protein, 1),
            "total_carbohydrates": round(total_carbohydrates, 1),
            "total_fat": round(total_fat, 1),
            "breakfast_calories": breakfast_calories,
            "lunch_calories": lunch_calories,
            "dinner_calories": dinner_calories,
            "snack_calories": snack_calories,
            "meal_count": meal_count,
            "daily_calorie_goal": daily_calorie_goal
        }
        
        # Store the summary
        insert_result = (
            supabase.table("daily_summaries")
            .insert(new_summary)
            .execute()
        )
        
        print(f"Created new summary: {new_summary}")
        
        # Build meal breakdown
        meal_breakdown = {
            'breakfast': {'calories': breakfast_calories, 'count': 1 if breakfast_calories > 0 else 0},
            'lunch': {'calories': lunch_calories, 'count': 1 if lunch_calories > 0 else 0},
            'dinner': {'calories': dinner_calories, 'count': 1 if dinner_calories > 0 else 0},
            'snack': {'calories': snack_calories, 'count': 1 if snack_calories > 0 else 0},
        }
        
        return DailySummaryDashboard(
            date=query_date.isoformat(),
            total_calories=total_calories,
            total_protein=round(total_protein, 1),
            total_carbohydrates=round(total_carbohydrates, 1),
            total_fat=round(total_fat, 1),
            breakfast_calories=breakfast_calories,
            lunch_calories=lunch_calories,
            dinner_calories=dinner_calories,
            snack_calories=snack_calories,
            meal_count=meal_count,
            daily_calorie_goal=daily_calorie_goal,
            meal_breakdown=meal_breakdown,
            success=True
        )
        
    except Exception as e:
        print(f"ERROR in get_daily_summary: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get daily summary: {str(e)}"
        )

@router.post("/", response_model=DailySummaryResponse, status_code=status.HTTP_201_CREATED)
async def create_or_update_daily_summary(
    payload: DailySummaryCreate,
    current_user: dict = Depends(get_current_user)
):
    """Create or update daily summary (used by triggers/automation)."""
    supabase = get_supabase_admin()
    user_id = current_user["id"]
    
    # Check if summary exists for this date
    existing = (
        supabase.table("daily_summaries")
        .select("id")
        .eq("user_id", user_id)
        .eq("date", payload.date)
        .maybe_single()
        .execute()
    )
    
    summary_data = payload.model_dump()
    summary_data["user_id"] = user_id
    
    if existing.data:
        # Update existing
        result = (
            supabase.table("daily_summaries")
            .update(summary_data)
            .eq("id", existing.data["id"])
            .execute()
        )
        return result.data[0]
    else:
        # Create new
        result = (
            supabase.table("daily_summaries")
            .insert(summary_data)
            .execute()
        )
        return result.data[0]

@router.post("/recalculate", response_model=dict)
async def recalculate_daily_summary(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    """Recalculate daily summary for a specific date (for manual updates/backfill)."""
    try:
        supabase = get_supabase_admin()
        user_id = current_user["id"]
        
        # Delete existing summary for this date
        supabase.table("daily_summaries").delete().eq("user_id", user_id).eq("date", date).execute()
        
        # Get fresh summary (will calculate and store new one)
        summary = await get_daily_summary(date=date, current_user=current_user)
        
        return {
            "success": True,
            "message": f"Daily summary for {date} recalculated successfully",
            "summary": summary
        }
        
    except Exception as e:
        return {
            "success": False,
            "message": f"Failed to recalculate summary: {str(e)}"
        }
