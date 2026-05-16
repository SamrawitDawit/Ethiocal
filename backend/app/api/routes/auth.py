# ============================================
# EthioCal — Authentication Routes
# ============================================
# POST /register  — create account via Supabase Auth
# POST /login     — sign in via Supabase Auth
# ============================================

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials

from app.core.dependencies import get_current_auth_user, security
from app.db.supabase import get_supabase, get_supabase_admin
from app.schemas.user import (
    AuthCallbackExchangeRequest,
    AuthResponse,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    UserCreate,
    UserLogin,
)
from app.services.user_health_conditions import get_user_profile_with_health

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
    options = {
        "data": {
            "full_name": payload.full_name,
        }
    }
    if payload.email_redirect_to:
        options["email_redirect_to"] = payload.email_redirect_to

    try:
        auth_response = supabase.auth.sign_up({
            "email": payload.email,
            "password": payload.password,
            "options": options,
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
    profile_result = (
        admin.table("profiles")
        .select("*")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )

    if profile_result.data:
        profile = profile_result.data
    else:
        # Create profile manually if trigger didn't run
        insert_result = (
            admin.table("profiles")
            .insert({
                "id": user_id,
                "email": payload.email,
                "full_name": payload.full_name,
            })
            .execute()
        )
        profile = insert_result.data[0]

    profile = get_user_profile_with_health(admin, user_id, include_health_conditions=False) or profile

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
    profile = get_user_profile_with_health(
        admin,
        str(auth_response.user.id),
        include_health_conditions=False,
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    return AuthResponse(
        access_token=auth_response.session.access_token,
        refresh_token=auth_response.session.refresh_token,
        user=profile,
    )


@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordRequest):
    """Send a password reset email via Supabase Auth."""
    supabase = get_supabase()

    try:
        options = {}
        if payload.redirect_to:
            options["redirect_to"] = payload.redirect_to
        supabase.auth.reset_password_email(payload.email, options)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to send password reset email: {str(e)}",
        )

    return {"message": "Password reset email sent."}


@router.post("/exchange-callback", response_model=AuthResponse)
async def exchange_callback(payload: AuthCallbackExchangeRequest):
    """Exchange Supabase callback parameters into an authenticated session."""
    if not payload.token_hash or not payload.type:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing token_hash or callback type.",
        )

    supabase = get_supabase()

    try:
        auth_response = supabase.auth.verify_otp(
            {
                "token_hash": payload.token_hash,
                "type": payload.type,
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to exchange auth callback: {str(e)}",
        )

    if not auth_response.user or not auth_response.session:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Auth callback did not return a valid session.",
        )

    admin = get_supabase_admin()
    profile = get_user_profile_with_health(
        admin,
        str(auth_response.user.id),
        include_health_conditions=False,
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found.",
        )

    return AuthResponse(
        access_token=auth_response.session.access_token,
        refresh_token=auth_response.session.refresh_token,
        user=profile,
        email_confirmation_required=False,
    )


@router.post("/reset-password")
async def reset_password(
    payload: ResetPasswordRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    _auth_user: dict = Depends(get_current_auth_user),
):
    """Update the current user's password using the recovery session."""
    supabase = get_supabase()

    try:
        supabase.auth.set_session(
            credentials.credentials,
            payload.refresh_token or "",
        )
        supabase.auth.update_user({"password": payload.password})
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to reset password: {str(e)}",
        )

    return {"message": "Password updated successfully."}
