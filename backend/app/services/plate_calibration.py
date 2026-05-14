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
    
    def get_plate_relative_height(self, image: np.ndarray, depth_map: np.ndarray) -> Optional[float]:
        """Get the relative height of the plate rim from depth data.
        
        Uses the detected plate mask to sample depth values at the plate rim.
        
        Args:
            image: RGB image for plate detection
            depth_map: Depth map from Depth Anything V2 (relative depths, 0-1 range)
            
        Returns:
            Relative height value of the plate rim, or None if not found
        """
        try:
            # Get plate mask using CV detection
            plate_mask = self.plate_detector.get_plate_mask(image)
            
            if plate_mask is None:
                logger.warning("Could not create plate mask for height detection")
                return None
            
            if depth_map is None or depth_map.size == 0:
                logger.warning("No depth map provided for height detection")
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
                return float(plate_relative_height)
            else:
                logger.warning("No depth values found within plate mask")
                return None
                
        except Exception as e:
            logger.warning(f"Getting plate relative height failed: {e}")
            return None
    
    
    def calculate_real_world_volume(
        self,
        relative_height: float,
        pixel_area: int,
        pixel_to_cm_ratio: float
    ) -> Tuple[float, float]:
        """Calculate real-world volume from depth data.
    
    Args:
        relative_height: Relative height from depth detection
        pixel_area: Area in pixels
        pixel_to_cm_ratio: Conversion ratio from pixels to cm
        
    Returns:
        Tuple of (height_cm, volume_cm3)
    """
    # Convert pixel area to real-world area (cm²)
        area_cm2 = pixel_area * (pixel_to_cm_ratio ** 2)
    
    # Convert relative height to real-world height (cm)
    # Using plate-based calibration for accuracy
        height_cm = relative_height * 10  # Simple conversion factor
    
    # Calculate volume (cm³) = area (cm²) × height (cm)
    # No shape factor because density will handle the conversion to mass
        volume_cm3 = area_cm2 * height_cm
    
        logger.info(f"Volume calculation: area={area_cm2:.1f}cm², height={height_cm:.2f}cm, volume={volume_cm3:.1f}cm³")
    
        return height_cm, volume_cm3    
    def get_plate_calibration(self, image: np.ndarray, depth_map: np.ndarray = None) -> Dict[str, Any]:
        """Get complete plate calibration data for an image.
        
        Args:
            image: RGB image as numpy array
            depth_map: Optional depth map for height calibration
            
        Returns:
            Dictionary with calibration parameters
        """
        # Get horizontal calibration (diameter)
        pixel_to_cm_ratio = self.calculate_pixel_to_cm_ratio(image)
        plate_diameter_pixels = self._cached_plate_diameter_pixels
        
        # Get vertical calibration (height) if depth map provided
        plate_relative_height = None
        if depth_map is not None:
            plate_relative_height = self.get_plate_relative_height(image, depth_map)
        
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