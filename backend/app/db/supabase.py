# ============================================
# EthioCal — Supabase Client Setup
# ============================================
# Provides two Supabase clients:
#   - get_supabase()       → uses the anon key (respects RLS)
#   - get_supabase_admin() → uses service-role key (bypasses RLS)
# ============================================

from gotrue.http_clients import SyncClient as GoTrueHttpClient
from supabase import SupabaseAuthClient, create_client, Client

from app.core.config import settings


def _build_client(supabase_key: str) -> Client:
    client = create_client(settings.SUPABASE_URL, supabase_key)

    # Supabase Auth defaults to httpx's short timeout, which is too aggressive
    # for slower verification/reset email delivery paths.
    client.auth.close()
    client.auth = SupabaseAuthClient(
        url=f"{settings.SUPABASE_URL}/auth/v1",
        headers=client.options.headers,
        auto_refresh_token=client.options.auto_refresh_token,
        persist_session=client.options.persist_session,
        storage=client.options.storage,
        flow_type=client.options.flow_type,
        http_client=GoTrueHttpClient(
            timeout=settings.SUPABASE_AUTH_TIMEOUT_SECONDS,
            follow_redirects=True,
            http2=True,
        ),
    )
    client.auth.on_auth_state_change(client._listen_to_auth_events)
    return client


def get_supabase() -> Client:
    """Return a Supabase client using the public anon key.

    This client respects Row Level Security policies.
    Use it for operations that should be scoped to the
    authenticated user.
    """
    return _build_client(settings.SUPABASE_KEY)


def get_supabase_admin() -> Client:
    """Return a Supabase client using the service-role key.

    This client bypasses RLS — use it only for admin
    operations like the leaderboard or cross-user queries.
    """
    return _build_client(settings.SUPABASE_SERVICE_ROLE_KEY)
