# ============================================
# EthioCal — Supabase Client Setup
# ============================================
# Provides two Supabase clients:
#   - get_supabase()       → uses the anon key (respects RLS)
#   - get_supabase_admin() → uses service-role key (bypasses RLS)
# ============================================

from supabase import create_client, Client

from app.core.config import settings


def get_supabase() -> Client:
    """Return a Supabase client using the public anon key.

    This client respects Row Level Security policies.
    Use it for operations that should be scoped to the
    authenticated user.
    """
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)


def get_supabase_admin() -> Client:
    """Return a Supabase client using the service-role key.

    This client bypasses RLS — use it only for admin
    operations like the leaderboard or cross-user queries.
    """
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
