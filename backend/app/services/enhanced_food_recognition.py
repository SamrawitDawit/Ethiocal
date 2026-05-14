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
from app.services.plate_calibration import get_plate_calibrator

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
    image_np: np.ndarray
) -> List[Dict]:
    """Process combined YOLOv8 + Depth results into structured format.
    
    Args:
        yolo_results: YOLOv8 inference results
        depth_results: Depth estimation results from vision engine
        image_width: Original image width
        image_height: Original image height
        
    Returns:
        List of enhanced prediction dicts with depth/volume data
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
            
            # Add depth data if available
            if depth_results and i < len(depth_results):
                depth_data = depth_results[i]
                relative_height = depth_data.get("mean_relative_height", 0)
                pixel_area = depth_data.get("pixel_area", 0)
                
                # Calculate real-world volume using plate calibration
                estimated_volume_cm3 = None
                height_cm = None
                calibration_data = None
                
                if relative_height > 0 and pixel_area > 0:
                    try:
                        calibrator = get_plate_calibrator()
                        calibration = calibrator.get_plate_calibration(image_np)
                        pixel_to_cm_ratio = calibration["pixel_to_cm_ratio"]
                        
                        # Calculate real-world measurements
                        height_cm, volume_cm3 = calibrator.calculate_real_world_volume(
                            relative_height, pixel_area, pixel_to_cm_ratio
                        )
                        
                        estimated_volume_cm3 = round(volume_cm3, 1)
                        height_cm = round(height_cm, 2)
                        calibration_data = {
                            "plate_diameter_cm": calibration["plate_diameter_cm"],
                            "pixel_to_cm_ratio": round(pixel_to_cm_ratio, 4),
                            "calibration_method": calibration["calibration_method"]
                        }
                        
                        logger.info(f"Real-world volume: {volume_cm3:.1f} cm³, height: {height_cm:.2f} cm")
                        
                    except Exception as e:
                        logger.warning(f"Plate calibration failed: {e}")
                        # Fallback: use simple estimation
                        try:
                            # Simple fallback: assume plate is 60% of image width
                            image_width = image_np.shape[1]
                            estimated_plate_pixels = image_width * 0.6
                            fallback_pixel_to_cm = settings.PLATE_DIAMETER_CM / estimated_plate_pixels
                            
                            # Simple volume calculation
                            height_cm = relative_height * 10  # Rough conversion
                            area_cm2 = pixel_area * (fallback_pixel_to_cm ** 2)
                            volume_cm3 = area_cm2 * height_cm
                            
                            estimated_volume_cm3 = round(volume_cm3, 1)
                            height_cm = round(height_cm, 2)
                            calibration_data = {
                                "plate_diameter_cm": settings.PLATE_DIAMETER_CM,
                                "pixel_to_cm_ratio": round(fallback_pixel_to_cm, 4),
                                "calibration_method": "fallback_estimation"
                            }
                            
                            logger.info(f"Fallback volume: {volume_cm3:.1f} cm³, height: {height_cm:.2f} cm")
                            
                        except Exception as fallback_error:
                            logger.error(f"Fallback calculation also failed: {fallback_error}")
                            # Last resort: basic calculation
                            height_cm = round(relative_height * 5, 2)  # Very rough estimate
                            estimated_volume_cm3 = round(pixel_area * relative_height / 1000, 1)
                            calibration_data = {
                                "plate_diameter_cm": 25.0,
                                "pixel_to_cm_ratio": 0.04,
                                "calibration_method": "basic_estimation"
                            }
                
                prediction["depth_data"] = {
                    "mean_relative_height": round(relative_height, 6),
                    "pixel_area": pixel_area,
                    "height_cm": height_cm,
                    "estimated_volume_cm3": estimated_volume_cm3,
                    "calibration": calibration_data
                }
            
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
            verbose=False,
        )
        logger.info(f" YOLOv8 inference complete")

        # Run depth estimation if enabled
        logger.info(f"  6. Checking if depth detection is enabled...")
        logger.info(f"     ENABLE_DEPTH_DETECTION={settings.ENABLE_DEPTH_DETECTION}")
        depth_results = []
        if settings.ENABLE_DEPTH_DETECTION:
            logger.info(f"  7. Depth detection enabled, loading volume estimator...")
            try:
                logger.info(f"     Calling get_volume_estimator()...")
                volume_estimator = get_volume_estimator()
                logger.info(f"  Volume estimator loaded successfully")

                logger.info(f"  8. Running depth estimation...")
                depth_results = volume_estimator.estimate(image_np)
                logger.info(f" Depth estimation completed for {len(depth_results)} food items")
            except Exception as e:
                logger.error(f" Depth estimation failed: {type(e).__name__}: {e}", exc_info=True)
                depth_results = []
        else:
            logger.info(f"  Depth detection is DISABLED - skipping")

        # Process combined results
        logger.info(f"  9. Processing combined results...")
        predictions = process_enhanced_results(
            yolo_results, depth_results, image_width, image_height, image_np
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
