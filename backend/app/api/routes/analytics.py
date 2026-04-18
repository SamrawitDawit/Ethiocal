from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, Query
from app.db.supabase import get_supabase_admin
from app.core.dependencies import get_current_admin
from app.schemas.analytics import AnalyticsSummary, EngagementGraphResponse, DailyActivityPoint

router = APIRouter()

@router.get("/summary", response_model=AnalyticsSummary)
async def get_analytics_summary(_admin: dict = Depends(get_current_admin)):
    """
    Retrieve a summary of system-wide analytics.
    Accessible only by admins.
    """
    supabase = get_supabase_admin()
    
    # 1. Count non-admin users from profiles
    users_count = supabase.table("profiles") \
        .select("*", count="exact") \
        .neq("role", "admin") \
        .limit(0) \
        .execute()
    
    # 2. Count total health conditions
    health_count = supabase.table("health_conditions") \
        .select("*", count="exact") \
        .limit(0) \
        .execute()
        
    # 3. Count educational articles
    articles_count = supabase.table("education_articles") \
        .select("*", count="exact") \
        .limit(0) \
        .execute()
        
    # 4. Count meals logged today (engagement metric)
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    meals_today = supabase.table("meals") \
        .select("*", count="exact") \
        .gte("created_at", today_start) \
        .limit(0) \
        .execute()

    return AnalyticsSummary(
        total_users=users_count.count or 0,
        total_health_conditions=health_count.count or 0,
        total_educational_articles=articles_count.count or 0,
        meals_logged_today=meals_today.count or 0
    )

@router.get("/graph/daily-activity", response_model=EngagementGraphResponse)
async def get_daily_engagement_graph(
    days: int = Query(7, ge=1, le=30),
    _admin: dict = Depends(get_current_admin)
):
    """
    Retrieve data for meal logging activity graph.
    Returns counts of meals logged per day for the last X days.
    """
    supabase = get_supabase_admin()
    since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
    
    result = (
        supabase.table("meals")
        .select("created_at")
        .gte("created_at", since)
        .execute()
    )
    
    # Aggregate counts by date in Python (following leaderboard pattern)
    daily_counts = {}
    for meal in result.data:
        day_key = meal["created_at"][:10]  # YYYY-MM-DD
        daily_counts[day_key] = daily_counts.get(day_key, 0) + 1
        
    # Sort by date and format for graph
    graph_data = [
        {"day": k, "count": v} for k, v in sorted(daily_counts.items())
    ]
    
    return {"data": graph_data}
