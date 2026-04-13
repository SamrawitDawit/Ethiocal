from pydantic import BaseModel
from typing import List
from datetime import date

class CountResponse(BaseModel):
    count: int

class AnalyticsSummary(BaseModel):
    total_users: int
    total_health_conditions: int
    total_educational_articles: int
    meals_logged_today: int

class DailyActivityPoint(BaseModel):
    day: date
    count: int

class EngagementGraphResponse(BaseModel):
    data: List[DailyActivityPoint]
