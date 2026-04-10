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
      3. Create a matching row in the profiles table.
      4. Return the tokens and basic profile.

    Note: Health info setup is done separately via POST /api/v1/users/setup-profile.
    """
    supabase = get_supabase()

    try:
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
    admin = get_supabase_admin()

    # Check if profile was created by trigger, if not create it manually
    profile = None
    try:
        profile_result = (
            admin.table("profiles")
            .select("*")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to read profile after signup: {str(e)}",
        )

    if profile_result is not None and getattr(profile_result, "data", None):
        profile = profile_result.data
    else:
        # Create profile manually if trigger didn't run
        try:
            insert_result = (
                admin.table("profiles")
                .insert({
                    "id": user_id,
                    "email": payload.email,
                    "full_name": payload.full_name,
                })
                .execute()
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create profile row after signup: {str(e)}",
            )

        if not insert_result or not getattr(insert_result, "data", None):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Signup succeeded, but profile row could not be created.",
            )
        profile = insert_result.data[0]

    # Handle case where email confirmation is required (session will be None)
    if not auth_response.session:
        return AuthResponse(
            access_token="",
            refresh_token="",
            user=profile,
            email_confirmation_required=True,
        )

    return AuthResponse(
        access_token=auth_response.session.access_token,
        refresh_token=auth_response.session.refresh_token,
        user=profile,
        email_confirmation_required=False,
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
        .maybe_single()
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
