# ============================================
# EthioCal — FastAPI Application Entry Point
# ============================================
# Initialises the FastAPI app, registers route
# groups, and configures CORS.
# ============================================

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, food, meals, users, leaderboard
from app.utils.error_handlers import register_error_handlers


app = FastAPI(
    title="EthioCal API",
    description="Backend for tracking calories from Ethiopian foods using AI image recognition.",
    version="1.0.0",
)

# ---- CORS — allow mobile app to reach the API ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Error handlers ----
register_error_handlers(app)

# ---- Route registration ----
app.include_router(auth.router,        prefix="/api/v1/auth",        tags=["Authentication"])
app.include_router(food.router,        prefix="/api/v1/food",        tags=["Food Recognition"])
app.include_router(meals.router,       prefix="/api/v1/meals",       tags=["Meals"])
app.include_router(users.router,       prefix="/api/v1/users",       tags=["Users"])
app.include_router(leaderboard.router, prefix="/api/v1/leaderboard", tags=["Leaderboard"])


@app.get("/", tags=["Health"])
async def health_check():
    """Simple health-check endpoint."""
    return {"status": "healthy", "app": "EthioCal API"}
