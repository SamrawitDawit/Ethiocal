from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class NotificationPreferencesUpdate(BaseModel):
    meal_reminders: bool | None = None
    health_alerts: bool | None = None
    reminder_times: list[str] | None = None


class NotificationPreferencesResponse(BaseModel):
    id: str
    user_id: str
    meal_reminders: bool = True
    health_alerts: bool = True
    reminder_times: list[str] = ["08:00", "12:30", "18:30"]
    created_at: datetime
    updated_at: datetime


class NotificationResponse(BaseModel):
    id: str
    user_id: str
    type: Literal["meal_reminder", "health_alert"]
    title: str
    body: str
    is_read: bool = False
    created_at: datetime


class SendReminderRequest(BaseModel):
    user_id: str


class SendHealthAlertRequest(BaseModel):
    user_id: str
    nutrient: str
    current_amount: float
    threshold_amount: float
    threshold_unit: str
    condition_name: str
