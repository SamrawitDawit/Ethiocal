# ============================================
# EthioCal — Enhanced AI Food Recognition Service
# ============================================
# Combines YOLOv8 instance segmentation with Depth Anything V2
# to provide 3D food analysis (area + height) for better volume estimation.
# ============================================

import io
import logging
from pathlib import Path
from typing import Dict, List, Tuple, Optional

import cv2
import numpy as np
from PIL import Image
from ultralytics import YOLO

from app.core.config import settings
from app.vision_engine import FoodVolumeEstimator

logger = logging.getLogger(__name__)

# Global model instances (loaded once on first use)
_yolo_model: YOLO | None = None
_volume_estimator: FoodVolumeEstimator | None = None


def get_yolo_model() -> YOLO:
    """Load and cache the YOLOv8 model."""
    global _yolo_model
    if _yolo_model is None:
        model_path = Path(settings.YOLO_MODEL_PATH)
        if not model_path.exists():
            raise FileNotFoundError(
                f"YOLOv8 model not found at {model_path}. "
                "Please place your best.pt file in the models/ directory."
            )
        logger.info(f"Loading YOLOv8 model from {model_path}")
        _yolo_model = YOLO(str(model_path))
    return _yolo_model


def get_volume_estimator() -> FoodVolumeEstimator:
    """Load and cache the volume estimator with depth detection."""
    global _volume_estimator
    logger.info(f"[get_volume_estimator] Called, _volume_estimator is {_volume_estimator}")

    if _volume_estimator is None:
        logger.info(f"  Initializing new FoodVolumeEstimator...")
        if not settings.ENABLE_DEPTH_DETECTION:
            logger.error(f"  Depth detection is disabled in settings!")
            raise ValueError("Depth detection is disabled in settings")

        logger.info(f"  Creating FoodVolumeEstimator instance...")
        try:
            _volume_estimator = FoodVolumeEstimator()
            logger.info(f" Food Volume Estimator initialized successfully")
        except Exception as e:
            logger.error(f" Failed to initialize FoodVolumeEstimator: {type(e).__name__}: {e}", exc_info=True)
            raise
    else:
        logger.info(f"  Using cached FoodVolumeEstimator")

    return _volume_estimator


def process_enhanced_results(
    yolo_results,
    depth_results: List[Dict],
    image_width: int,
    image_height: int,
    image_np: np.ndarray,
    depth_map: np.ndarray = None
) -> List[Dict]:
    """Process combined YOLOv8 + Depth results into structured format.

    Args:
        yolo_results: YOLOv8 inference results
        depth_results: Depth estimation results from vision engine
        image_width: Original image width
        image_height: Original image height
        image_np: Image as numpy array
        depth_map: Depth map for height calibration (optional)

    Returns:
        List of enhanced prediction dicts with heuristic estimation data
    """
    predictions = []
    
    for result in yolo_results:
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
                
            # Extract bounding box coordinates
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            
            # Build base prediction
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
                "depth_data": None,
            }
            
            # Extract mask polygon if available
            if masks is not None and i < len(masks):
                mask_data = masks[i]
                
                if mask_data.xy is not None and len(mask_data.xy) > 0:
                    polygon = mask_data.xy[0].tolist()
                    
                    # Calculate area from polygon
                    area = None
                    if len(polygon) >= 3:
                        poly_array = np.array(polygon)
                        x = poly_array[:, 0]
                        y = poly_array[:, 1]
                        area = 0.5 * abs(np.dot(x, np.roll(y, 1)) - np.dot(y, np.roll(x, 1)))
                    
                    prediction["mask"] = {
                        "polygon": [[round(p[0], 2), round(p[1], 2)] for p in polygon],
                        "area": round(area, 2) if area else None,
                    }
            
            # Add heuristic estimation data if available
            # Match by bounding box center since both depth_results and predictions come from same YOLO detections
            if depth_results:
                pred_center_x = (x1 + x2) / 2
                pred_center_y = (y1 + y2) / 2

                matching_depth = None
                best_distance = float('inf')

                for depth_result in depth_results:
                    if "box" in depth_result:
                        depth_x1, depth_y1, depth_x2, depth_y2 = depth_result["box"]
                        depth_center_x = (depth_x1 + depth_x2) / 2
                        depth_center_y = (depth_y1 + depth_y2) / 2

                        # Calculate distance between centers
                        distance = ((pred_center_x - depth_center_x) ** 2 + (pred_center_y - depth_center_y) ** 2) ** 0.5
                        if distance < best_distance:
                            best_distance = distance
                            matching_depth = depth_result

                if matching_depth and best_distance < 50:  # Threshold for matching
                    # Use heuristic estimation data from vision engine
                    mask_pixel_count = int(matching_depth.get("mask_pixel_count", 0))
                    area_ratio = float(matching_depth.get("area_ratio", 0))
                    height_stats = matching_depth.get("height_stats", {})
                    estimated_grams = float(matching_depth.get("estimated_grams", 0))

                    prediction["depth_data"] = {
                        "pixel_area": mask_pixel_count,
                        "area_ratio": area_ratio,
                        "height_stats": height_stats,
                        "estimated_grams": estimated_grams,
                        "estimation_method": "heuristic"
                    }
                    logger.info(
                        f"Heuristic estimation for {label}: "
                        f"area_ratio={area_ratio:.4f}, "
                        f"mound_score={height_stats.get('effective', 0):.2f}, "
                        f"grams={estimated_grams:.1f}g"
                    )
                else:
                    # No matching depth data found for this label
                    # Include prediction anyway without depth data
                    logger.warning(f"No matching depth data found for label: {label}")

            
            predictions.append(prediction)
    
    return predictions


async def predict_food_with_depth(
    image_bytes: bytes,
    filename: str
) -> Tuple[List[Dict], int, int]:
    """Run enhanced food recognition with depth detection.

    Args:
        image_bytes: Raw image bytes
        filename: Original filename (for logging)

    Returns:
        Tuple of (enhanced predictions list, image_width, image_height)
        Each prediction dict includes:
            - label (str): predicted food name/class
            - confidence (float): 0-1 probability
            - bounding_box (dict): coordinates and dimensions
            - mask (dict): polygon coordinates and area
            - depth_data (dict): height and volume information
    """
    logger.info(f"[predict_food_with_depth] START - filename={filename}")

    # Load image and get dimensions
    logger.info(f"  1. Loading image from bytes ({len(image_bytes)} bytes)...")
    image = Image.open(io.BytesIO(image_bytes))
    image_width, image_height = image.size
    logger.info(f" Image loaded: {image_width}x{image_height}")

    # Convert to RGB if needed
    logger.info(f"  2. Converting to RGB (current mode: {image.mode})...")
    if image.mode != "RGB":
        image = image.convert("RGB")
    logger.info(f" RGB conversion done")

    # Convert to numpy array for depth processing
    logger.info(f"  3. Converting to numpy array...")
    image_np = np.array(image)
    logger.info(f" Numpy array created: shape={image_np.shape}")

    try:
        # Run YOLOv8 detection
        logger.info(f"  4. Getting YOLOv8 model...")
        yolo_model = get_yolo_model()
        logger.info(f" YOLOv8 model loaded")

        logger.info(f"  5. Running YOLOv8 inference...")
        yolo_results = yolo_model(
            image,
            conf=settings.YOLO_CONFIDENCE_THRESHOLD,
            task="segment",
            verbose=False,
        )
        logger.info(f" YOLOv8 inference complete")

        # Run depth estimation if enabled
        logger.info(f"  6. Checking if depth detection is enabled...")
        logger.info(f"     ENABLE_DEPTH_DETECTION={settings.ENABLE_DEPTH_DETECTION}")
        depth_results = []
        depth_map = None
        if settings.ENABLE_DEPTH_DETECTION:
            logger.info(f"  7. Depth detection enabled, loading volume estimator...")
            try:
                logger.info(f"     Calling get_volume_estimator()...")
                volume_estimator = get_volume_estimator()
                logger.info(f"  Volume estimator loaded successfully")

                logger.info(f"  8. Running depth estimation with YOLO results...")
                depth_results, depth_map = volume_estimator.estimate(image_np, yolo_results=yolo_results)
                logger.info(f" Depth estimation completed for {len(depth_results)} food items")
            except Exception as e:
                logger.error(f" Depth estimation failed: {type(e).__name__}: {e}", exc_info=True)
                depth_results = []
        else:
            logger.info(f"  Depth detection is DISABLED - skipping")

        # Process combined results
        logger.info(f"  9. Processing combined results...")
        predictions = process_enhanced_results(
            yolo_results, depth_results, image_width, image_height, image_np, depth_map
        )
        logger.info(f" Enhanced detection completed: {len(predictions)} food items")

        logger.info(f"[predict_food_with_depth] SUCCESS")
        return predictions, image_width, image_height

    except FileNotFoundError as e:
        logger.error(f" Model not found: {e}")
        raise FileNotFoundError(
            f"Required model not found. Please check your model paths in settings."
        )
    except Exception as e:
        logger.error(f" Error during enhanced food recognition: {type(e).__name__}: {e}", exc_info=True)
        raise


async def predict_food_fallback(
    image_bytes: bytes, 
    filename: str
) -> Tuple[List[Dict], int, int]:
    """Fallback to basic YOLOv8 detection if depth detection fails.
    
    This maintains backward compatibility with the original food_recognition.py
    """
    from app.services.food_recognition import predict_food
    
    logger.info(f"Falling back to basic YOLOv8 detection for {filename}")
    return await predict_food(image_bytes, filename)
