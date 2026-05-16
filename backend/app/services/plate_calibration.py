"""Plate calibration using OpenCV detection."""

import logging
from typing import Optional, Tuple, Dict, Any

import cv2
import numpy as np

from app.core.config import settings
from app.services.plate_detector import PlateDetector

logger = logging.getLogger(__name__)


class PlateCalibrator:
    """Converts pixel measurements to real-world centimeters using plate calibration."""
    
    def __init__(self):
        self.plate_diameter_cm = settings.PLATE_DIAMETER_CM
        self.plate_depth_cm = getattr(settings, 'PLATE_DEPTH_CM', 2.5)  # Default 2.5cm rim height

        # Use OpenCV-based plate detector (no ML model needed)
        self.plate_detector = PlateDetector()

        # Cache for current image calibration
        self._cached_pixel_to_cm_ratio = None
        self._cached_plate_diameter_pixels = None
        self._cached_plate_relative_height = None
        
    def detect_plate_diameter_pixels(self, image: np.ndarray) -> Optional[float]:
        """Detect plate diameter in pixels.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Plate diameter in pixels, or None if not detected
        """
        try:
            diameter = self.plate_detector.get_plate_diameter_pixels(image)
            if diameter:
                self._cached_plate_diameter_pixels = diameter
                logger.info(f"Detected plate diameter: {diameter:.1f} pixels")
            return diameter
        except Exception as e:
            logger.warning(f"Plate diameter detection failed: {e}")
            return None
    
    def calculate_pixel_to_cm_ratio(self, image: np.ndarray) -> float:
        """Calculate pixel-to-cm ratio using plate detection or fallback.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Pixel to cm conversion ratio (cm per pixel)
        """
        # If we've already calculated a ratio for this image, reuse it
        if self._cached_pixel_to_cm_ratio is not None:
            logger.info(f"Using cached pixel-to-cm ratio: {self._cached_pixel_to_cm_ratio:.4f} cm/pixel")
            return self._cached_pixel_to_cm_ratio

        # Try to detect plate automatically
        plate_diameter_pixels = self.detect_plate_diameter_pixels(image)
        
        if plate_diameter_pixels and plate_diameter_pixels > 0:
            # Calculate ratio from detected plate
            pixel_to_cm = self.plate_diameter_cm / plate_diameter_pixels
            self._cached_pixel_to_cm_ratio = pixel_to_cm
            logger.info(f"Auto-calculated pixel-to-cm ratio: {pixel_to_cm:.4f} cm/pixel")
            return pixel_to_cm
        else:
            # Fallback: estimate based on image dimensions
            # Assume plate occupies about 60% of image width
            image_width = image.shape[1]
            estimated_plate_pixels = image_width * 0.6
            pixel_to_cm = self.plate_diameter_cm / estimated_plate_pixels
            self._cached_pixel_to_cm_ratio = pixel_to_cm
            logger.info(f"Using fallback pixel-to-cm ratio: {pixel_to_cm:.4f} cm/pixel (estimated plate: {estimated_plate_pixels:.1f}px)")
            return pixel_to_cm
    
    def get_plate_relative_height(self, image: np.ndarray, depth_map: np.ndarray, skip_detection: bool = False) -> Optional[float]:
        """Get the relative height of the plate rim from depth data.

        Uses the detected plate mask to sample depth values at the plate rim.

        Args:
            image: RGB image for plate detection
            depth_map: Depth map from Depth Anything V2 (relative depths, 0-1 range)
            skip_detection: If True, skip plate detection and use a simple center region

        Returns:
            Relative height value of the plate rim, or None if not found
        """
        # Use cached value if available
        if self._cached_plate_relative_height is not None:
            logger.info(f"Using cached plate relative height: {self._cached_plate_relative_height:.4f}")
            return self._cached_plate_relative_height

        if depth_map is None or depth_map.size == 0:
            logger.warning("No depth map provided for height detection")
            return None

        try:
            if skip_detection:
                # Fast path: use center region of image instead of detecting plate
                h, w = depth_map.shape[:2]
                # Use center 50% of image as plate region (fast fallback)
                y1, y2 = h // 4, 3 * h // 4
                x1, x2 = w // 4, 3 * w // 4
                plate_depth_values = depth_map[y1:y2, x1:x2].flatten()
                logger.info(f"Using center region for plate height (skipped detection)")
            else:
                # Get plate mask using CV detection
                plate_mask = self.plate_detector.get_plate_mask(image)

                if plate_mask is None:
                    logger.warning("Could not create plate mask for height detection")
                    return None

                # Ensure depth map is same size as mask
                if depth_map.shape[:2] != plate_mask.shape:
                    depth_map = cv2.resize(depth_map, (plate_mask.shape[1], plate_mask.shape[0]))

                # Get depth values only where plate is detected
                plate_depth_values = depth_map[plate_mask > 0]

            if len(plate_depth_values) > 0:
                # The rim is typically the highest point (closest to camera)
                # Use 95th percentile to avoid noise from reflections
                plate_relative_height = np.percentile(plate_depth_values, 95)

                # Also get the average for comparison
                plate_avg_height = np.mean(plate_depth_values)

                logger.info(f"Detected plate relative height: {plate_relative_height:.4f} "
                          f"(avg: {plate_avg_height:.4f}, samples: {len(plate_depth_values)})")
                self._cached_plate_relative_height = float(plate_relative_height)
                return self._cached_plate_relative_height
            else:
                logger.warning("No depth values found within plate region")
                return None

        except Exception as e:
            logger.warning(f"Getting plate relative height failed: {e}")
            return None
    
    
    def calculate_real_world_volume(
        self,
        relative_height: float,
        pixel_area: int,
        pixel_to_cm_ratio: float,
        max_raw_height: float = None,
        plate_relative_height: float = None
    ) -> Tuple[float, float]:
        """Calculate real-world volume from depth data.

    Args:
        relative_height: Relative height from depth detection (0-1 normalized within food item)
        pixel_area: Area in pixels
        pixel_to_cm_ratio: Conversion ratio from pixels to cm
        max_raw_height: Maximum raw height from depth model (optional)
        plate_relative_height: Detected plate rim relative height from depth map (optional)

    Returns:
        Tuple of (height_cm, volume_cm3)
    """
    # Convert pixel area to real-world area (cm²)
        area_cm2 = pixel_area * (pixel_to_cm_ratio ** 2)

    # Convert relative height to real-world height (cm)
    # Use plate rim calibration if available (plate rim ~ 2.5cm)
        if plate_relative_height and plate_relative_height > 0:
            # Use plate rim as height reference: if plate rim shows depth value of X,
            # and plate is ~2.5cm high, then depth_to_cm_ratio = 2.5 / plate_relative_height
            plate_depth_cm = self.plate_depth_cm  # Default 2.5cm
            depth_to_cm_ratio = plate_depth_cm / plate_relative_height if plate_relative_height > 0 else 1.0

            # For normalized relative height, we need to estimate what depth_unit value represents
            # Use max_raw_height if available, otherwise assume reasonable default
            if max_raw_height and max_raw_height > 0:
                height_cm = max_raw_height * depth_to_cm_ratio
            else:
                # Fallback: assume normalized height spans similar range to plate
                # So height_cm = relative_height * plate_depth_cm
                height_cm = relative_height * plate_depth_cm

            logger.info(f"Using plate calibration: plate_depth={plate_depth_cm}cm, "
                       f"depth_to_cm_ratio={depth_to_cm_ratio:.4f}, height={height_cm:.2f}cm")
        else:
            # Fallback: use conservative multiplier (was 10, reduced to 5)
            height_cm = relative_height * 5.0
            logger.info(f"Using fallback height multiplier (no plate calibration): height={height_cm:.2f}cm")

    # Calculate volume (cm³) = area (cm²) × height (cm)
        volume_cm3 = area_cm2 * height_cm

        logger.info(f"Volume calculation: area={area_cm2:.1f}cm², height={height_cm:.2f}cm, volume={volume_cm3:.1f}cm³")

        return height_cm, volume_cm3    
    def get_plate_calibration(self, image: np.ndarray, depth_map: np.ndarray = None, skip_detection: bool = False) -> Dict[str, Any]:
        """Get complete plate calibration data for an image.

        Args:
            image: RGB image as numpy array
            depth_map: Optional depth map for height calibration
            skip_detection: If True, skip plate detection and use fallback estimation (faster)

        Returns:
            Dictionary with calibration parameters
        """
        # Get horizontal calibration (diameter) - skip expensive detection if requested
        if skip_detection:
            # Fast path: use fallback without running expensive plate detection
            image_width = image.shape[1]
            estimated_plate_pixels = image_width * 0.6
            pixel_to_cm_ratio = self.plate_diameter_cm / estimated_plate_pixels
            self._cached_pixel_to_cm_ratio = pixel_to_cm_ratio
            plate_diameter_pixels = None
        else:
            pixel_to_cm_ratio = self.calculate_pixel_to_cm_ratio(image)
            plate_diameter_pixels = self._cached_plate_diameter_pixels

        # Get vertical calibration (height) if depth map provided
        plate_relative_height = None
        if depth_map is not None:
            plate_relative_height = self.get_plate_relative_height(image, depth_map, skip_detection=skip_detection)

        calibration_method = "auto_detected" if plate_diameter_pixels else "estimated"
        if plate_relative_height:
            calibration_method += "_with_height"

        return {
            "plate_diameter_cm": self.plate_diameter_cm,
            "plate_depth_cm": self.plate_depth_cm,
            "plate_diameter_pixels": plate_diameter_pixels,
            "pixel_to_cm_ratio": round(pixel_to_cm_ratio, 4),
            "plate_relative_height": plate_relative_height,
            "calibration_method": calibration_method,
            "has_height_reference": plate_relative_height is not None
        }
    
    def pixels_to_cm(self, pixels: float, pixel_to_cm_ratio: float = None) -> float:
        """Convert pixels to centimeters."""
        if pixel_to_cm_ratio is None:
            pixel_to_cm_ratio = self._cached_pixel_to_cm_ratio
            if pixel_to_cm_ratio is None:
                raise ValueError("No pixel_to_cm_ratio available. Run calculate_pixel_to_cm_ratio first.")
        
        return pixels * pixel_to_cm_ratio


# Global calibrator instance
_calibrator: PlateCalibrator | None = None


def get_plate_calibrator() -> PlateCalibrator:
    """Get the global plate calibrator instance."""
    global _calibrator
    if _calibrator is None:
        _calibrator = PlateCalibrator()
    return _calibrator