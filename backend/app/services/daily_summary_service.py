from datetime import datetime, date
from typing import Dict, Any, Optional
from app.db.supabase import get_supabase_admin
from app.services.streak_service import StreakService

class DailySummaryService:
    """Service to manage daily summaries with API-level logic"""
    
    @staticmethod
    async def update_daily_summary(
        user_id: str, 
        meal_date: date,
        operation: str = "upsert"
    ) -> Dict[str, Any]:
        """
        Update daily summary for a specific date and user.
        Operation can be: 'upsert', 'delete', 'recalculate'
        """
        print(f"\n=== DailySummaryService.update_daily_summary ===")
        print(f"User ID: {user_id}")
        print(f"Meal Date: {meal_date}")
        print(f"Operation: {operation}")
        
        try:
            supabase = get_supabase_admin()
            
            # Get user's daily calorie goal
            print("Getting user profile...")
            profile_result = (
                supabase.table("profiles")
                .select("daily_calorie_goal")
                .eq("id", user_id)
                .maybe_single()
                .execute()
            )
            print(f"Profile result: {profile_result.data}")
            daily_calorie_goal = profile_result.data.get("daily_calorie_goal", 2000) if profile_result.data else 2000
            print(f"Daily calorie goal: {daily_calorie_goal}")
            
            # Calculate date range for meals
            start_datetime = datetime.combine(meal_date, datetime.min.time())
            end_datetime = datetime.combine(meal_date, datetime.max.time())
            
            if operation == "delete":
                # For delete operation, remove the summary and let it be recalculated on next request
                supabase.table("daily_summaries").delete().eq("user_id", user_id).eq("date", meal_date.isoformat()).execute()
                return {"success": True, "message": "Daily summary deleted"}
            
            # Get meals for date
            print("Getting meals for date...")
            print(f"Date range: {start_datetime.isoformat()} to {end_datetime.isoformat()}")
            meals_result = (
                supabase.table("meals")
                .select("id, meal_type, total_calories, created_at")
                .eq("user_id", user_id)
                .gte("created_at", start_datetime.isoformat())
                .lte("created_at", end_datetime.isoformat())
                .execute()
            )
            
            print(f"Meals query result: {meals_result.data}")
            if meals_result.data:
                print(f"Found {len(meals_result.data)} meals")
                for i, meal in enumerate(meals_result.data):
                    print(f"  Meal {i+1}: {meal['meal_type']} - {meal['total_calories']} calories - {meal['created_at']}")
            else:
                print("No meals found for this date")
            
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
                print(f"Meal IDs for nutrient calculation: {meal_ids}")
                
                # Get food items for nutrient calculation
                print("Getting food items for nutrient calculation...")
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
                
                print(f"Food items result: {food_items_result.data}")
                
                # Calculate nutrient totals
                print("Calculating nutrient totals...")
                for item in (food_items_result.data or []):
                    quantity = item.get("quantity", 1)
                    food_item = item.get("food_item")
                    
                    if food_item:
                        serving_multiplier = quantity
                        total_protein += (food_item.get("protein", 0) * serving_multiplier)
                        total_carbohydrates += (food_item.get("carbohydrates", 0) * serving_multiplier)
                        total_fat += (food_item.get("fat", 0) * serving_multiplier)
                print(f"Meal breakdown - Breakfast: {breakfast_calories}, Lunch: {lunch_calories}, Dinner: {dinner_calories}, Snack: {snack_calories}")
                print(f"Nutrient totals - Protein: {total_protein:.1f}, Carbs: {total_carbohydrates:.1f}, Fat: {total_fat:.1f}")
            
            # Create or update daily summary
            summary_data = {
                "user_id": user_id,
                "date": meal_date.isoformat(),
                "total_calories": round(total_calories),
                "total_protein": round(total_protein, 1),
                "total_carbohydrates": round(total_carbohydrates, 1),
                "total_fat": round(total_fat, 1),
                "breakfast_calories": round(breakfast_calories),
                "lunch_calories": round(lunch_calories),
                "dinner_calories": round(dinner_calories),
                "snack_calories": round(snack_calories),
                "meal_count": meal_count,
                "daily_calorie_goal": daily_calorie_goal
            }
            
            print(f"Summary data to upsert: {summary_data}")
            
            # Upsert summary
            print("Upserting daily summary...")
            result = (
                supabase.table("daily_summaries")
                .upsert(summary_data, on_conflict="user_id,date")
                .execute()
            )
            
            print(f"Upsert result: {result.data}")
            
            # Update streak after successful summary update
            if result.data:
                await StreakService.update_streak(user_id)
            
            return {
                "success": True,
                "summary": result.data[0] if result.data else None,
                "message": f"Daily summary updated for {meal_date.isoformat()}"
            }
            
        except Exception as e:
            print(f"Error updating daily summary: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    @staticmethod
    async def recalculate_all_summaries() -> Dict[str, Any]:
        """Recalculate all daily summaries (for backfill)"""
        try:
            supabase = get_supabase_admin()
            
            # Get all users
            users_result = supabase.table("profiles").select("id").execute()
            
            if not users_result.data:
                return {"success": False, "error": "No users found"}
            
            total_updated = 0
            
            for user in users_result.data:
                user_id = user["id"]
                
                # Get all dates with meals for this user
                dates_result = (
                    supabase.table("meals")
                    .select("created_at")
                    .eq("user_id", user_id)
                    .execute()
                )
                
                if dates_result.data:
                    # Get unique dates
                    unique_dates = set()
                    for meal in dates_result.data:
                        unique_dates.add(datetime.fromisoformat(meal["created_at"]).date())
                    
                    # Update summary for each date
                    for meal_date in unique_dates:
                        result = await DailySummaryService.update_daily_summary(user_id, meal_date)
                        if result["success"]:
                            total_updated += 1
            
            return {
                "success": True,
                "total_updated": total_updated,
                "message": f"Recalculated {total_updated} daily summaries"
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
