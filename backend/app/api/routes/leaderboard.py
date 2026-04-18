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
    limit: int = Query(100, ge=1, le=500),
    _current_user: dict = Depends(get_current_user),
):
    """Return a leaderboard ranked by streak and goal performance.

    Shows all users with active streaks, ranked by:
    - Current streak (primary)
    - Best streak (secondary)
    - Days met goal (tertiary)

    This logic runs in Python because Supabase's PostgREST API
    does not support the complex GROUP BY / subquery needed.
    For production, consider creating a Postgres function or view.
    """
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    supabase = get_supabase_admin()

    # Fetch ALL profiles with streaks > 0
    profiles_result = (
        supabase.table("profiles")
            .select("id, full_name, daily_calorie_goal, current_streak, best_streak")
            .gt("current_streak", 0)
            .execute()
    )
    profiles = {p["id"]: p for p in profiles_result.data}
    user_ids = list(profiles.keys())

    # Fetch recent meals to calculate days met goal (optional for ranking)
    if user_ids:
        result = (
            supabase.table("meals")
            .select("user_id, total_calories, created_at")
            .gte("created_at", since)
            .in_("user_id", user_ids)
            .execute()
        )
        logs = result.data
    else:
        logs = []

    # Group calories by (user_id, date) to count days goal was met
    daily_totals: dict[tuple[str, str], float] = {}
    for log in logs:
        day_key = log["created_at"][:10]  # extract YYYY-MM-DD
        key = (log["user_id"], day_key)
        daily_totals[key] = daily_totals.get(key, 0.0) + log["total_calories"]

    # Count days where user met their goal
    user_days_met: dict[str, int] = {}
    for (uid, _day), cals in daily_totals.items():
        profile = profiles.get(uid)
        if profile and cals <= profile["daily_calorie_goal"]:
            user_days_met[uid] = user_days_met.get(uid, 0) + 1

    # Build sorted entries with weighted score
    entries = []
    user_scores = []

    for uid, profile in profiles.items():
        current_streak = profile.get("current_streak", 0)
        best_streak = profile.get("best_streak", 0)
        days_met = user_days_met.get(uid, 0)

        # Calculate weighted score: (current_streak * 0.6) + (best_streak * 0.3) + (days_met_goal * 0.1)
        weighted_score = (current_streak * 0.6) + (best_streak * 0.3) + (days_met * 0.1)

        user_scores.append({
            "user_id": uid,
            "full_name": profile.get("full_name", "Unknown"),
            "days_goal_met": days_met,
            "current_streak": current_streak,
            "best_streak": best_streak,
            "weighted_score": weighted_score
        })

    # Sort by weighted score (descending)
    user_scores.sort(key=lambda x: x["weighted_score"], reverse=True)

    for user in user_scores[:limit]:
        entries.append(
            LeaderboardEntry(
                user_id=user["user_id"],
                full_name=user["full_name"],
                days_goal_met=user["days_goal_met"],
                current_streak=user["current_streak"],
                best_streak=user["best_streak"]
            )
        )

    return LeaderboardResponse(entries=entries, total=len(entries))
