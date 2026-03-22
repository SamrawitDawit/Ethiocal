from pydantic_settings import BaseSettings
from pathlib import Path
import os

# Get the absolute path to the .env file
BASE_DIR = Path(__file__).resolve().parent.parent.parent
env_file = BASE_DIR / '.env'

class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_JWT_SECRET: str

    class Config:
        # Tell Pydantic to read the .env file directly
        env_file = str(env_file)
        env_file_encoding = 'utf-8'
        case_sensitive = True

# This line will now automatically read from the .env file specified in the Config class
settings = Settings()