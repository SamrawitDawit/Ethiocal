# ============================================
# EthioCal — Global Error Handlers
# ============================================
# Registers exception handlers on the FastAPI
# app so errors return consistent JSON.
# ============================================

import traceback

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError


def register_error_handlers(app: FastAPI) -> None:
    """Attach custom exception handlers to the application."""

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(_request: Request, exc: RequestValidationError):
        """Return 422 with a structured error body on invalid request data."""
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={
                "detail": "Validation error",
                "errors": exc.errors(),
            },
        )

    @app.exception_handler(Exception)
    async def general_error_handler(_request: Request, exc: Exception):
        """Catch-all: return 500 without leaking internal details."""
        # Log the actual error with full traceback for debugging
        print(f"Unhandled error: {exc}")
        traceback.print_exc()
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "An unexpected error occurred. Please try again later."},
        )
