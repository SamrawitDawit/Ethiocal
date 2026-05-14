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
    YOLO_MODEL_PATH: str = "app/models/best.pt"  # Path to YOLOv8 segmentation model
    YOLO_CONFIDENCE_THRESHOLD: float = 0.25  # Minimum confidence for detections
    
    # --- Depth Anything V2 Configuration ---
    DEPTH_MODEL_PATH: str = "app/checkpoints/depth_anything_v2_vitb.pth"  # Path to depth model weights
    DEPTH_MODEL_TYPE: str = "vitb"  # Model type: vitb, vitl, or vitg
    ENABLE_DEPTH_DETECTION: bool = True  # Toggle depth detection on/off
    
    # --- Plate Calibration System ---
    PLATE_DIAMETER_CM: float = 25.0  # Standard dinner plate diameter in cm
    PLATE_DEPTH_CM: float = 2.0  # Plate depth/height in cm (for baseline)
    PIXEL_TO_CM_RATIO: float | None = None  # Will be calculated dynamically

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


# Singleton instance — import this wherever settings are needed.
settings = Settings()
