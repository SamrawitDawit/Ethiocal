# ============================================
# EthioCal — FastAPI Dependencies
# ============================================
# Verifies the Supabase JWT from the
# Authorization header and returns the
# current user's profile from the database.
# ============================================

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.db.supabase import get_supabase_admin

# HTTPBearer extracts the token from "Authorization: Bearer <token>"
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verify the Supabase access token and return the user's profile row.

    Steps:
      1. Use the Supabase admin client to validate the JWT and get the auth user.
      2. Fetch the matching row from the 'profiles' table.
      3. Raise 401 if the token is invalid or the profile is missing.
    """
    token = credentials.credentials
    supabase = get_supabase_admin()

    try:
        # Supabase auth.get_user() validates the JWT and returns the auth user
        auth_response = supabase.auth.get_user(token)
        auth_user = auth_response.user

        if auth_user is None:
            raise ValueError("No user returned")
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )

    # Fetch the user's profile from the profiles table
    result = (
        supabase.table("profiles")
        .select("*")
        .eq("id", str(auth_user.id))
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Complete registration first.",
        )

    return result.data

async def get_current_auth_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verify the Supabase access token and return the auth user ID.

    Does NOT check the 'profiles' table. Use this for the POST /profile
    endpoint where the profile row does not exist yet.
    """
    token = credentials.credentials
    supabase = get_supabase_admin()

    try:
        auth_response = supabase.auth.get_user(token)
        auth_user = auth_response.user

        if auth_user is None:
            raise ValueError("No user returned")
        
        return {"id": str(auth_user.id), "email": auth_user.email}
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )
