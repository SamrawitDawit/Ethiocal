# ============================================
# EthioCal — User Schemas
# ============================================
# Request / response shapes for user endpoints.
# ============================================

from datetime import datetime

from pydantic import BaseModel, EmailStr


# --- Registration ---

class UserCreate(BaseModel):
    """Payload sent when a new user registers.

    email and password are handled by Supabase Auth.
    Extra fields are passed as user_metadata and stored
    in the profiles table by a database trigger.
    """
    email: EmailStr
    password: str
    full_name: str
    has_diabetes: bool = False
    has_hypertension: bool = False
    has_heart_disease: bool = False
    daily_calorie_goal: float = 2000.0


# --- Login ---

class UserLogin(BaseModel):
    """Payload sent when a user logs in."""
    email: EmailStr
    password: str


# --- Profile update ---

class UserUpdate(BaseModel):
    """Fields a user can update on their profile."""
    full_name: str | None = None
    has_diabetes: bool | None = None
    has_hypertension: bool | None = None
    has_heart_disease: bool | None = None
    daily_calorie_goal: float | None = None


# --- Responses ---

class UserResponse(BaseModel):
    """Public-facing representation of a user profile."""
    id: str
    email: str
    full_name: str
    has_diabetes: bool
    has_hypertension: bool
    has_heart_disease: bool
    daily_calorie_goal: float
    is_active: bool
    created_at: datetime


class AuthResponse(BaseModel):
    """Response returned after successful login or registration."""
    access_token: str
    refresh_token: str
    user: UserResponse
