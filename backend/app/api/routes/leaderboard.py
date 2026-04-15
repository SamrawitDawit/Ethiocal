# ============================================
# EthioCal — Leaderboard Routes
# ============================================
# GET / — ranked list of users by how many
#          days they've met their calorie goal
# ============================================

from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.leaderboard import LeaderboardEntry, LeaderboardResponse

router = APIRouter()


@router.get("/", response_model=LeaderboardResponse)
async def get_leaderboard(
    days: int = Query(30, ge=1, le=365, description="Look-back window in days."),
    limit: int = Query(20, ge=1, le=100),
    _current_user: dict = Depends(get_current_user),
):
    """Return a leaderboard ranked by number of days users met their calorie goal.

    Algorithm:
      1. Fetch all meal_logs from the look-back period.
      2. Group by user and calendar day, summing calories.
      3. Count how many days each user stayed within their goal.
      4. Rank by that count (descending).

    This logic runs in Python because Supabase's PostgREST API
    does not support the complex GROUP BY / subquery needed.
    For production, consider creating a Postgres function or view.
    """
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    supabase = get_supabase_admin()

    # Fetch profiles for all users who have meal data
    # First get users who have meals in the lookback period
    users_with_meals_result = (
        supabase.table("meals")
            .select("user_id")
            .gte("created_at", since)
            .execute()
    )
    user_ids = list({log["user_id"] for log in users_with_meals_result.data})
    
    profiles_result = (
        supabase.table("profiles")
            .select("id, full_name, daily_calorie_goal, current_streak, best_streak")
            .in_("id", user_ids)
            .execute()
    )
    profiles = {p["id"]: p for p in profiles_result.data}

    # Fetch recent meal logs with user profile data
    result = (
        supabase.table("meal_logs")
        .select("user_id, total_calories, created_at")
        .gte("created_at", since)
        .execute()
    )
    logs = result.data

    if not logs:
        return LeaderboardResponse(entries=[], total=0)

    # Group calories by (user_id, date)
    daily_totals: dict[tuple[str, str], float] = {}
    for log in logs:
        day_key = log["created_at"][:10]  # extract YYYY-MM-DD
        key = (log["user_id"], day_key)
        daily_totals[key] = daily_totals.get(key, 0.0) + log["total_calories"]

    # Count days where user met their goal
    user_days_met: dict[str, int] = {}
    user_streak: dict[str, int] = {}

    for (uid, _day), cals in daily_totals.items():
        profile = profiles.get(uid)
        if profile and cals <= profile["daily_calorie_goal"]:
            user_days_met[uid] = user_days_met.get(uid, 0) + 1

    # Build sorted entries
    entries = []
    for uid, days_met in sorted(user_days_met.items(), key=lambda x: x[1], reverse=True)[:limit]:
        profile = profiles.get(uid, {})
        entries.append(
            LeaderboardEntry(
                user_id=uid,
                full_name=profile.get("full_name", "Unknown"),
                days_goal_met=days_met,
                current_streak=profile.get("current_streak", 0),
                best_streak=profile.get("best_streak", 0)
            )
        )

    return LeaderboardResponse(entries=entries, total=len(entries))
