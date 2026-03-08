# ============================================
# EthioCal — Authentication Routes
# ============================================
# POST /register  — create account via Supabase Auth
# POST /login     — sign in via Supabase Auth
# ============================================

from fastapi import APIRouter, HTTPException, status

from app.db.supabase import get_supabase, get_supabase_admin
from app.schemas.user import UserCreate, UserLogin, AuthResponse

router = APIRouter()


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: UserCreate):
    """Register a new user via Supabase Auth.

    Steps:
      1. Call Supabase sign_up with email, password, and user metadata.
      2. Supabase creates the auth user and issues tokens.
      3. A database trigger auto-creates a matching row in the profiles table.
      4. Update the profile with health fields that don't fit in user_metadata.
      5. Return the tokens and profile.
    """
    supabase = get_supabase()

    try:
        # Sign up through Supabase Auth — full_name is stored in user_metadata
        auth_response = supabase.auth.sign_up({
            "email": payload.email,
            "password": payload.password,
            "options": {
                "data": {
                    "full_name": payload.full_name,
                }
            }
        })
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Registration failed: {str(e)}",
        )

    if not auth_response.user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration failed. Email may already be in use.",
        )

    user_id = str(auth_response.user.id)

    # Update the profile with health condition fields.
    # The trigger already created the profile row with id, email, full_name.
    admin = get_supabase_admin()
    admin.table("profiles").update({
        "has_diabetes": payload.has_diabetes,
        "has_hypertension": payload.has_hypertension,
        "has_heart_disease": payload.has_heart_disease,
        "daily_calorie_goal": payload.daily_calorie_goal,
    }).eq("id", user_id).execute()

    # Fetch the completed profile to return
    profile = (
        admin.table("profiles")
        .select("*")
        .eq("id", user_id)
        .single()
        .execute()
    )

    return AuthResponse(
        access_token=auth_response.session.access_token,
        refresh_token=auth_response.session.refresh_token,
        user=profile.data,
    )


@router.post("/login", response_model=AuthResponse)
async def login(payload: UserLogin):
    """Sign in with email + password via Supabase Auth.

    Returns access and refresh tokens plus the user profile.
    The mobile app should store these tokens and send the access_token
    as `Authorization: Bearer <token>` on subsequent requests.
    """
    supabase = get_supabase()

    try:
        auth_response = supabase.auth.sign_in_with_password({
            "email": payload.email,
            "password": payload.password,
        })
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    if not auth_response.user or not auth_response.session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    # Fetch the user's profile
    admin = get_supabase_admin()
    profile = (
        admin.table("profiles")
        .select("*")
        .eq("id", str(auth_response.user.id))
        .single()
        .execute()
    )

    if not profile.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    return AuthResponse(
        access_token=auth_response.session.access_token,
        refresh_token=auth_response.session.refresh_token,
        user=profile.data,
    )
