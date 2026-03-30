# ============================================
# EthioCal — FastAPI Dependencies
# ============================================
# Verifies the Supabase JWT from the
# Authorization header and returns the
# current user's profile from the database.
# Includes role-based access control.
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


async def get_current_admin(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Require the current user to have admin role.

    Use as a dependency for admin-only endpoints.
    """
    if current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required.",
        )
    return current_user


def require_role(allowed_roles: list[str]):
    """Factory function to create a role-checking dependency.

    Usage:
        @router.get("/admin-only", dependencies=[Depends(require_role(["admin"]))])
        async def admin_only_endpoint():
            ...
    """
    async def role_checker(current_user: dict = Depends(get_current_user)) -> dict:
        user_role = current_user.get("role", "user")
        if user_role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role: {', '.join(allowed_roles)}.",
            )
        return current_user
    return role_checker


async def get_current_auth_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verify the Supabase access token and return the auth user (not the profile).

    This is used when you need the raw auth user data, not the profile data.
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

    return {"id": str(auth_user.id), "email": auth_user.email}

    
