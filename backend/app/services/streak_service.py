from datetime import datetime, date, timedelta
from typing import Dict, Any, Optional
from app.db.supabase import get_supabase_admin

class StreakService:
    """Service to manage user streaks for meal logging consistency"""
    
    @staticmethod
    async def update_streak(user_id: str) -> Dict[str, Any]:
        """
        Update user's streak based on today's meal logging.
        Called after a meal is created for the current date.
        """
        try:
            supabase = get_supabase_admin()
            today = date.today()
            
            print(f"\n=== StreakService.update_streak ===")
            print(f"User ID: {user_id}")
            print(f"Today: {today}")
            
            # Get current user profile
            profile_result = (
                supabase.table("profiles")
                .select("current_streak, best_streak, last_meal_date")
                .eq("id", user_id)
                .maybe_single()
                .execute()
            )
            
            if not profile_result.data:
                print("No profile found for user")
                return {"success": False, "error": "Profile not found"}
            
            profile = profile_result.data
            current_streak = profile.get("current_streak", 0)
            best_streak = profile.get("best_streak", 0)
            last_meal_date = profile.get("last_meal_date")
            
            print(f"Current profile - Streak: {current_streak}, Best: {best_streak}, Last meal: {last_meal_date}")
            
            # Check if user has logged a meal today
            meals_today_result = (
                supabase.table("meals")
                .select("id")
                .eq("user_id", user_id)
                .gte("created_at", datetime.combine(today, datetime.min.time()).isoformat())
                .lte("created_at", datetime.combine(today, datetime.max.time()).isoformat())
                .limit(1)
                .execute()
            )
            
            has_meal_today = len(meals_today_result.data) > 0 if meals_today_result.data else False
            print(f"Has meal today: {has_meal_today}")
            
            new_streak = current_streak
            new_best_streak = best_streak
            
            if has_meal_today:
                if last_meal_date:
                    # Check if yesterday had a meal (continuing streak)
                    yesterday = today - timedelta(days=1)
                    yesterday_had_meal = await StreakService._had_meal_on_date(user_id, yesterday)
                    
                    if yesterday_had_meal:
                        # Continuing streak
                        new_streak = current_streak + 1
                        print(f"Continuing streak: {current_streak} -> {new_streak}")
                    else:
                        # Streak broken - start new streak at 1
                        new_streak = 1
                        print(f"Streak broken: was {current_streak}, now {new_streak}")
                else:
                    # First meal ever
                    new_streak = 1
                    print(f"First meal ever: starting streak at 1")
            else:
                # No meal today - streak is broken
                if last_meal_date:
                    # Check if last meal was yesterday
                    yesterday = today - timedelta(days=1)
                    if last_meal_date == yesterday:
                        # Last meal was yesterday, but no meal today - streak broken
                        new_streak = 0
                        print(f"Streak broken: was {current_streak}, now 0 (missed today)")
                    else:
                        # Already missed previous days - streak already broken
                        new_streak = 0
                        print(f"Streak already broken: remains 0")
                else:
                    # Never had a meal before
                    new_streak = 0
                    print("No meals ever recorded, streak remains 0")
            
            # Update best streak if current is better
            if new_streak > best_streak:
                new_best_streak = new_streak
                print(f"New best streak: {best_streak} -> {new_best_streak}")
            else:
                new_best_streak = best_streak
            
            # Update profile
            update_data = {
                "current_streak": new_streak,
                "best_streak": new_best_streak,
                "last_meal_date": today if has_meal_today else last_meal_date
            }
            
            print(f"Updating profile with: {update_data}")
            
            result = (
                supabase.table("profiles")
                .update(update_data)
                .eq("id", user_id)
                .execute()
            )
            
            return {
                "success": True,
                "current_streak": new_streak,
                "best_streak": new_best_streak,
                "had_meal_today": has_meal_today,
                "message": f"Streak updated to {new_streak}"
            }
            
        except Exception as e:
            print(f"Error updating streak: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    @staticmethod
    async def _had_meal_on_date(user_id: str, target_date: date) -> bool:
        """Check if user had a meal on specific date"""
        try:
            supabase = get_supabase_admin()
            
            meals_result = (
                supabase.table("meals")
                .select("id")
                .eq("user_id", user_id)
                .gte("created_at", datetime.combine(target_date, datetime.min.time()).isoformat())
                .lte("created_at", datetime.combine(target_date, datetime.max.time()).isoformat())
                .limit(1)
                .execute()
            )
            
            return len(meals_result.data) > 0 if meals_result.data else False
            
        except Exception as e:
            print(f"Error checking meal on date {target_date}: {e}")
            return False
