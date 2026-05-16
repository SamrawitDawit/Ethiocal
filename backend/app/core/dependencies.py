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
from jwt import ExpiredSignatureError, InvalidTokenError, decode as jwt_decode, get_unverified_header
from time import monotonic

from app.core.config import settings
from app.db.supabase import get_supabase_admin
from app.services.user_health_conditions import get_user_profile_with_health

# HTTPBearer extracts the token from "Authorization: Bearer <token>"
security = HTTPBearer()
_TOKEN_CACHE_TTL_SECONDS = 300.0
_token_claims_cache: dict[str, tuple[float, dict]] = {}


def _get_auth_claims(token: str, supabase) -> dict:
    """Validate a Supabase access token and return its claims.

    Supabase projects that use the shared JWT secret can be validated locally,
    which avoids a network round trip on every authenticated request. If the
    project is configured with asymmetric signing, fall back to Supabase's
    claim verification.
    """
    cached = _token_claims_cache.get(token)
    if cached is not None:
        cached_at, claims = cached
        if monotonic() - cached_at < _TOKEN_CACHE_TTL_SECONDS:
            return claims
        _token_claims_cache.pop(token, None)

    try:
        header = get_unverified_header(token)
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        ) from exc

    try:
        if header.get("alg") == "HS256" or "kid" not in header:
            claims = jwt_decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
            _token_claims_cache[token] = (monotonic(), claims)
            return claims

        claims_response = supabase.auth.get_claims(token)
        if claims_response is None or not claims_response.claims:
            raise ValueError("No claims returned")

        _token_claims_cache[token] = (monotonic(), claims_response.claims)
        return claims_response.claims
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        ) from exc
    except HTTPException:
        raise
    except Exception:
        try:
            auth_response = supabase.auth.get_user(token)
            auth_user = auth_response.user
            if auth_user is None:
                raise ValueError("No user returned")

            claims = {"sub": str(auth_user.id), "email": auth_user.email}
            _token_claims_cache[token] = (monotonic(), claims)
            return claims
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token.",
            ) from exc

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Verify the Supabase access token and return the user's profile row.

    Steps:
      1. Validate the JWT locally when possible and read the auth claims.
      2. Fetch the matching row from the 'profiles' table.
      3. Raise 401 if the token is invalid or the profile is missing.
    """
    token = credentials.credentials
    supabase = get_supabase_admin()
    claims = _get_auth_claims(token, supabase)

    user_id = str(claims.get("sub") or "")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )

    profile = get_user_profile_with_health(supabase, user_id)

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Complete registration first.",
        )

    return profile


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
    claims = _get_auth_claims(token, supabase)

    user_id = str(claims.get("sub") or "")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )

    return {"id": user_id, "email": claims.get("email")}

    
