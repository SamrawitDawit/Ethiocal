# ===========================================
# EthioCal — Application Configuration
# ===========================================
# Loads environment variables and exposes them
# as typed settings using pydantic-settings.
# ===========================================

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Central settings loaded from environment variables / .env file."""

    # --- Supabase ---
    SUPABASE_URL: str
    SUPABASE_KEY: str                          # anon / public key
    SUPABASE_SERVICE_ROLE_KEY: str             # service-role key (admin access, bypasses RLS)
    SUPABASE_JWT_SECRET: str                   # for verifying Supabase-issued JWTs

    # --- Image Upload ---
    MAX_IMAGE_SIZE_MB: int = 10
    STORAGE_BUCKET: str = "food-images"        # Supabase Storage bucket name

    # --- AI Food Recognition ---
    AI_MODEL_API_URL: str = ""
    AI_MODEL_API_KEY: str = ""

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


# Singleton instance — import this wherever settings are needed.
settings = Settings()
