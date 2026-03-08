# ============================================
# EthioCal — Leaderboard Schemas
# ============================================

from pydantic import BaseModel


class LeaderboardEntry(BaseModel):
    """One row on the leaderboard."""
    user_id: str
    full_name: str
    days_goal_met: int
    current_streak: int


class LeaderboardResponse(BaseModel):
    """Paginated leaderboard."""
    entries: list[LeaderboardEntry]
    total: int
