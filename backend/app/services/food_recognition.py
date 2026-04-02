# ============================================
# EthioCal — AI Food Recognition Service
# ============================================
# Uses a local YOLOv8 instance segmentation model
# to detect and segment foods in uploaded images.
# ============================================

import io
import logging
from pathlib import Path

import numpy as np
from PIL import Image
from ultralytics import YOLO

from app.core.config import settings

logger = logging.getLogger(__name__)

# Global model instance (loaded once on first use)
_model: YOLO | None = None


def get_model() -> YOLO:
    """Load and cache the YOLOv8 model."""
    global _model
    if _model is None:
        model_path = Path(settings.YOLO_MODEL_PATH)
        if not model_path.exists():
            raise FileNotFoundError(
                f"YOLOv8 model not found at {model_path}. "
                "Please place your best.pt file in the models/ directory."
            )
        logger.info(f"Loading YOLOv8 model from {model_path}")
        _model = YOLO(str(model_path))
    return _model


def process_segmentation_results(results, image_width: int, image_height: int) -> list[dict]:
    """Process YOLOv8 segmentation results into a structured format.

    Args:
        results: YOLOv8 inference results
        image_width: Original image width
        image_height: Original image height

    Returns:
        List of prediction dicts with label, confidence, bbox, and mask data
    """
    predictions = []

    for result in results:
        boxes = result.boxes
        masks = result.masks
        names = result.names

        if boxes is None:
            continue

        for i, box in enumerate(boxes):
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            label = names[class_id]

            # Skip low confidence detections
            if confidence < settings.YOLO_CONFIDENCE_THRESHOLD:
                continue

            # Extract bounding box coordinates (xyxy format)
            x1, y1, x2, y2 = box.xyxy[0].tolist()

            prediction = {
                "label": label,
                "confidence": round(confidence, 4),
                "bounding_box": {
                    "x1": round(x1, 2),
                    "y1": round(y1, 2),
                    "x2": round(x2, 2),
                    "y2": round(y2, 2),
                    "width": round(x2 - x1, 2),
                    "height": round(y2 - y1, 2),
                },
                "mask": None,
            }

            # Extract mask polygon if available
            if masks is not None and i < len(masks):
                mask_data = masks[i]

                # Get polygon coordinates (xy format, scaled to original image)
                if mask_data.xy is not None and len(mask_data.xy) > 0:
                    polygon = mask_data.xy[0].tolist()

                    # Calculate approximate area from polygon
                    area = None
                    if len(polygon) >= 3:
                        # Shoelace formula for polygon area
                        poly_array = np.array(polygon)
                        x = poly_array[:, 0]
                        y = poly_array[:, 1]
                        area = 0.5 * abs(np.dot(x, np.roll(y, 1)) - np.dot(y, np.roll(x, 1)))

                    prediction["mask"] = {
                        "polygon": [[round(p[0], 2), round(p[1], 2)] for p in polygon],
                        "area": round(area, 2) if area else None,
                    }

            predictions.append(prediction)

    return predictions


async def predict_food(image_bytes: bytes, filename: str) -> tuple[list[dict], int, int]:
    """Run YOLOv8 instance segmentation on the image.

    Args:
        image_bytes: Raw image bytes
        filename: Original filename (for logging)

    Returns:
        Tuple of (predictions list, image_width, image_height)
        Each prediction dict has:
            - label (str): predicted food name/class
            - confidence (float): 0-1 probability
            - bounding_box (dict): x1, y1, x2, y2, width, height
            - mask (dict): polygon coordinates and area
    """
    # Load image and get dimensions
    image = Image.open(io.BytesIO(image_bytes))
    image_width, image_height = image.size

    # Convert to RGB if needed (YOLO expects RGB)
    if image.mode != "RGB":
        image = image.convert("RGB")

    try:
        model = get_model()

        # Run inference
        results = model(
            image,
            conf=settings.YOLO_CONFIDENCE_THRESHOLD,
            verbose=False,
        )

        # Process results
        predictions = process_segmentation_results(results, image_width, image_height)

        logger.info(f"Detected {len(predictions)} food items in {filename}")
        return predictions, image_width, image_height

    except FileNotFoundError as e:
        logger.error(f"YOLOv8 model not found: {e}")
        raise FileNotFoundError(
            f"YOLOv8 model not found at '{settings.YOLO_MODEL_PATH}'. "
            "Please ensure your best.pt file is placed in the correct directory."
        )
    except Exception as e:
        logger.error(f"Error during food recognition: {e}")
        raise
