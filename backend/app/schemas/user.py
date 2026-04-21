# ============================================
# EthioCal — User Schemas
# ============================================
# Request / response shapes for user endpoints.
# ============================================

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr


# --- Registration ---

class UserCreate(BaseModel):
    """Payload sent when a new user registers."""
    email: EmailStr
    password: str
    full_name: str


# --- Login ---

class UserLogin(BaseModel):
    """Payload sent when a user logs in."""
    email: EmailStr
    password: str


# --- User Profile Setup ---

class UserProfileSetup(BaseModel):
    """Payload for completing user profile setup."""
    age: int | None = None
    gender: Literal["Male", "Female"] | None = None
    height: float | None = None
    weight: float | None = None
    activity_level: Literal["Sedentary", "Lightly Active", "Moderately Active", "Very Active"] | None = None
    daily_calorie_goal: float = 2000.0
    has_diabetes: bool = False
    has_hypertension: bool = False
    has_high_cholesterol: bool = False
    diabetes_type: Literal["Type 1", "Type 2"] | None = None
    latest_hba1c: float | None = None
    health_condition_ids: list[str] = []


class UserProfileUpdate(BaseModel):
    """Fields a user can update on their profile."""
    full_name: str | None = None
    language_preference: Literal["English", "Amharic"] | None = None


class UserProfileDataUpdate(BaseModel):
    """Update user profile data (age, weight, etc.)."""
    age: int | None = None
    gender: Literal["Male", "Female"] | None = None
    height: float | None = None
    weight: float | None = None
    activity_level: Literal["Sedentary", "Lightly Active", "Moderately Active", "Very Active"] | None = None
    daily_calorie_goal: float | None = None
    has_diabetes: bool | None = None
    has_hypertension: bool | None = None
    has_high_cholesterol: bool | None = None
    diabetes_type: Literal["Type 1", "Type 2"] | None = None
    latest_hba1c: float | None = None


# --- Health Conditions ---

class HealthConditionCreate(BaseModel):
    """Create a new health condition (admin only)."""
    condition_name: str
    restricted_nutrient: Literal["Sugar", "Sodium", "Fat", "Cholesterol"]
    threshold_amount: float
    threshold_unit: Literal["mg", "g", "kcal"]


class HealthConditionResponse(BaseModel):
    """Health condition data."""
    id: str
    condition_name: str
    restricted_nutrient: str
    threshold_amount: float
    threshold_unit: str


class UserHealthConditionAdd(BaseModel):
    """Add a health condition to a user."""
    health_condition_id: str


# --- Responses ---

class UserProfileDataResponse(BaseModel):
    """User profile data (extended)."""
    id: str
    user_id: str
    age: int | None = None
    gender: str | None = None
    height: float | None = None
    weight: float | None = None
    activity_level: str | None = None
    daily_calorie_goal: float = 2000.0
    has_diabetes: bool = False
    has_hypertension: bool = False
    has_high_cholesterol: bool = False
    diabetes_type: str | None = None
    latest_hba1c: float | None = None
    created_at: datetime


class UserResponse(BaseModel):
    """Public-facing representation of a user."""
    id: str
    email: str
    full_name: str
    role: str = "user"
    language_preference: str = "English"
    is_active: bool
    created_at: datetime
    profile: UserProfileDataResponse | None = None
    health_conditions: list[HealthConditionResponse] = []


class UserBasicResponse(BaseModel):
    """Basic user info including profile data."""
    id: str
    email: str
    full_name: str
    role: str = "user"
    language_preference: str = "English"
    is_active: bool
    # Extended profile fields
    age: int | None = None
    gender: str | None = None
    height: float | None = None
    weight: float | None = None
    activity_level: str | None = None
    daily_calorie_goal: float = 2000.0
    has_diabetes: bool = False
    has_hypertension: bool = False
    has_high_cholesterol: bool = False
    diabetes_type: str | None = None
    latest_hba1c: float | None = None
    created_at: datetime


class AuthResponse(BaseModel):
    """Response returned after successful login or registration."""
    access_token: str
    refresh_token: str
    user: UserBasicResponse
    email_confirmation_required: bool = False
