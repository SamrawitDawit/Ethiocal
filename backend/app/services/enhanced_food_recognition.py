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
        List of enhanced prediction dicts with depth/volume data
    """
    predictions = []
    # Precompute plate calibration once per image to avoid repeated expensive detection
    try:
        calibrator = get_plate_calibrator()
        # Skip expensive circle/ellipse detection on first pass - use fast fallback instead
        # We still get plate_relative_height from depth map which is already computed
        precomputed_calibration = calibrator.get_plate_calibration(image_np, depth_map, skip_detection=True)
        logger.info(f"Precomputed plate calibration: {precomputed_calibration}")
    except Exception as e:
        logger.warning(f"Precomputing plate calibration failed: {e}")
        precomputed_calibration = None
    
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
            # Match by food_type instead of index to ensure correct association
            if depth_results:
                matching_depth = None
                for depth_result in depth_results:
                    if depth_result.get("food_type") == label:
                        matching_depth = depth_result
                        break

                if matching_depth:
                    depth_data = matching_depth
                    pixel_area = int(depth_data.get("pixel_area", 0))
                    height_stats = depth_data.get("height_stats", {})
                else:
                    # No matching depth data found for this label
                    continue

                # Calculate real-world volume using robust height statistics
                estimated_volume_cm3 = None
                height_cm = None
                calibration_data = None

                if pixel_area > 0 and height_stats.get("effective", 0) > 0:
                    try:
                        # Use precomputed calibration when available
                        if precomputed_calibration:
                            calibration = precomputed_calibration
                            pixel_to_cm_ratio = calibration["pixel_to_cm_ratio"]
                            plate_relative_height = calibration.get("plate_relative_height")
                        else:
                            # Last resort: create a calibrator and compute on-demand
                            calibrator = get_plate_calibrator()
                            calibration = calibrator.get_plate_calibration(image_np, depth_map)
                            pixel_to_cm_ratio = calibration["pixel_to_cm_ratio"]
                            plate_relative_height = calibration.get("plate_relative_height")

                        # Compute depth_to_cm_ratio for height conversion
                        calibrator = get_plate_calibrator()
                        plate_depth_cm = 2.5
                        if plate_relative_height and plate_relative_height > 0:
                            depth_to_cm_ratio = plate_depth_cm / plate_relative_height
                            logger.info(f"Using plate calibration: depth_to_cm_ratio={depth_to_cm_ratio:.4f}")
                        else:
                            # Fallback: conservative estimate
                            max_raw_height = height_stats.get("max", 0)
                            if max_raw_height > 0:
                                depth_to_cm_ratio = 5.0 / max_raw_height
                            else:
                                depth_to_cm_ratio = 1.0
                            logger.info(f"Using fallback depth_to_cm_ratio={depth_to_cm_ratio:.4f}")

                        # Use robust effective height (0.3*mean + 0.7*p75)
                        effective_height_raw = float(height_stats.get("effective", 0))
                        effective_height_cm = effective_height_raw * depth_to_cm_ratio
                        height_cm = float(round(effective_height_cm, 2))

                        # Calculate volume using area × height formula
                        pixel_to_cm_ratio_sq = pixel_to_cm_ratio ** 2
                        area_cm2 = pixel_area * pixel_to_cm_ratio_sq
                        volume_cm3 = area_cm2 * effective_height_cm

                        estimated_volume_cm3 = round(volume_cm3, 1)

                        calibration_data = {
                            "plate_diameter_cm": calibration.get("plate_diameter_cm"),
                            "pixel_to_cm_ratio": round(pixel_to_cm_ratio, 4) if pixel_to_cm_ratio else None,
                            "calibration_method": calibration.get("calibration_method") if calibration else None
                        }

                        logger.info(
                            f"Robust height volume: "
                            f"area={area_cm2:.1f}cm² × "
                            f"effective_height={effective_height_cm:.2f}cm = "
                            f"{volume_cm3:.1f}cm³ (height_stats: mean={height_stats.get('mean', 0):.2f}, p75={height_stats.get('p75', 0):.2f})"
                        )

                    except Exception as e:
                        logger.warning(f"Robust height volume calculation failed: {e}")
                        # Fallback: use simple estimation
                        try:
                            # Simple fallback: assume plate is 60% of image width
                            image_width = image_np.shape[1]
                            estimated_plate_pixels = image_width * 0.6
                            fallback_pixel_to_cm = settings.PLATE_DIAMETER_CM / estimated_plate_pixels

                            # Use robust height if available
                            effective_height_raw = float(height_stats.get("effective", height_stats.get("mean", 0.5)))
                            fallback_depth_to_cm = 1.0
                            effective_height_cm = effective_height_raw * fallback_depth_to_cm
                            height_cm = float(round(effective_height_cm, 2))

                            # Volume = area × height
                            pixel_to_cm_ratio_sq = fallback_pixel_to_cm ** 2
                            area_cm2 = pixel_area * pixel_to_cm_ratio_sq
                            volume_cm3 = area_cm2 * effective_height_cm

                            estimated_volume_cm3 = round(volume_cm3, 1)
                            calibration_data = {
                                "plate_diameter_cm": settings.PLATE_DIAMETER_CM,
                                "pixel_to_cm_ratio": round(fallback_pixel_to_cm, 4),
                                "calibration_method": "fallback_robust_height"
                            }

                            logger.info(f"Fallback robust height: volume={volume_cm3:.1f}cm³, height={height_cm:.2f}cm")

                        except Exception as fallback_error:
                            logger.error(f"Fallback calculation also failed: {fallback_error}")
                            # Last resort: use p75 height from stats
                            p75_height = float(height_stats.get("p75", 0))
                            if p75_height > 0:
                                height_cm = float(round(p75_height, 2))
                                area_cm2 = pixel_area * (settings.PLATE_DIAMETER_CM / (image_np.shape[1] * 0.6)) ** 2
                                volume_cm3 = area_cm2 * p75_height
                                estimated_volume_cm3 = round(volume_cm3, 1)
                            else:
                                estimated_volume_cm3 = None
                                height_cm = None

                            calibration_data = {
                                "plate_diameter_cm": settings.PLATE_DIAMETER_CM,
                                "pixel_to_cm_ratio": settings.PLATE_DIAMETER_CM / (image_np.shape[1] * 0.6),
                                "calibration_method": "fallback_p75_height"
                            }
                            logger.warning(f"Using fallback p75 height: {height_cm}cm")

                prediction["depth_data"] = {
                    "pixel_area": pixel_area,
                    "height_cm": height_cm,
                    "estimated_volume_cm3": estimated_volume_cm3,
                    "height_stats": height_stats,
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
        depth_map = None
        if settings.ENABLE_DEPTH_DETECTION:
            logger.info(f"  7. Depth detection enabled, loading volume estimator...")
            try:
                logger.info(f"     Calling get_volume_estimator()...")
                volume_estimator = get_volume_estimator()
                logger.info(f"  Volume estimator loaded successfully")

                logger.info(f"  8. Running depth estimation...")
                depth_results, depth_map = volume_estimator.estimate(image_np)
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
