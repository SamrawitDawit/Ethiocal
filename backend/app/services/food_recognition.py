# ============================================
# EthioCal — AI Food Recognition Service
# ============================================
# Sends an uploaded image to the external AI
# model and returns predicted labels.
# ============================================

import httpx

from app.core.config import settings


async def predict_food(image_bytes: bytes, filename: str) -> list[dict]:
    """Call the external AI model and return a list of predictions.

    Each prediction dict has:
        - label (str):      predicted food name / class
        - confidence (float): 0-1 probability

    Replace the placeholder implementation below with your actual
    model API contract (e.g. a custom TensorFlow Serving endpoint,
    Roboflow, Clarifai, or a self-hosted model).
    """
    if not settings.AI_MODEL_API_URL:
        # Return mock data when no AI endpoint is configured.
        # This lets you develop and test the rest of the backend.
        return [
            {"label": "doro_wot", "confidence": 0.92},
            {"label": "injera", "confidence": 0.88},
        ]

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            settings.AI_MODEL_API_URL,
            headers={"Authorization": f"Bearer {settings.AI_MODEL_API_KEY}"},
            files={"image": (filename, image_bytes, "image/jpeg")},
        )
        response.raise_for_status()
        data = response.json()

    # Normalise — adapt this mapping to match your model's response format.
    return [
        {"label": p.get("label", p.get("class", "")), "confidence": p.get("confidence", 0.0)}
        for p in data.get("predictions", [])
    ]
