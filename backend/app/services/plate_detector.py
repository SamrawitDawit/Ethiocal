"""Plate detection """

import logging
import numpy as np
import cv2
from typing import Optional, Tuple, Dict, Any

logger = logging.getLogger(__name__)


class PlateDetector:
    """Detect plates using Hough Circle Transform and contour analysis."""
    
    def __init__(self, config: Dict[str, Any] = None):
        """Initialize plate detector with configurable parameters.
        
        Args:
            config: Optional configuration dict with keys:
                - min_radius_ratio: Minimum plate radius as fraction of image width (default: 0.2)
                - max_radius_ratio: Maximum plate radius as fraction of image width (default: 0.45)
                - hough_dp: Inverse ratio of accumulator resolution (default: 1)
                - hough_min_dist: Minimum distance between circle centers (default: 50)
                - hough_param1: Higher threshold for Canny edge detection (default: 50)
                - hough_param2: Accumulator threshold for circle detection (default: 30)
                - ellipse_aspect_ratio_max: Max aspect ratio for ellipse detection (default: 1.5)
        """
        self.config = config or {}
        
        # Circle detection parameters
        self.min_radius_ratio = self.config.get('min_radius_ratio', 0.2)
        self.max_radius_ratio = self.config.get('max_radius_ratio', 0.45)
        self.hough_dp = self.config.get('hough_dp', 1)
        self.hough_min_dist = self.config.get('hough_min_dist', 50)
        self.hough_param1 = self.config.get('hough_param1', 50)
        self.hough_param2 = self.config.get('hough_param2', 30)
        
        # Ellipse detection parameters
        self.ellipse_aspect_ratio_max = self.config.get('ellipse_aspect_ratio_max', 1.5)
        
        # Edge detection parameters
        self.canny_low = self.config.get('canny_low', 50)
        self.canny_high = self.config.get('canny_high', 150)
        
    def detect_plate_circle(self, image: np.ndarray) -> Optional[Tuple[Tuple[int, int], float]]:
        """Detect circular plate using Hough Circle Transform.
        
        Best for top-down or near-top-down shots where plate appears circular.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Tuple of (center (x, y), radius_pixels) or None if not found
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            
            # Apply Gaussian blur to reduce noise
            blurred = cv2.GaussianBlur(gray, (9, 9), 2)
            
            # Calculate min and max radii based on image dimensions
            img_height, img_width = image.shape[:2]
            min_radius = int(img_width * self.min_radius_ratio)
            max_radius = int(img_width * self.max_radius_ratio)
            
            # Detect circles using Hough Transform
            circles = cv2.HoughCircles(
                blurred,
                cv2.HOUGH_GRADIENT,
                dp=self.hough_dp,
                minDist=self.hough_min_dist,
                param1=self.hough_param1,
                param2=self.hough_param2,
                minRadius=min_radius,
                maxRadius=max_radius
            )
            
            if circles is not None:
                circles = np.round(circles[0, :]).astype("int")
                
                # Find the largest circle (most likely the main plate)
                largest_circle = max(circles, key=lambda x: x[2])
                center = (largest_circle[0], largest_circle[1])
                radius = float(largest_circle[2])
                
                logger.info(f"Detected circular plate: center={center}, radius={radius:.1f}px")
                return center, radius
            
            return None
            
        except Exception as e:
            logger.warning(f"Circle detection failed: {e}")
            return None
    
    def detect_plate_ellipse(self, image: np.ndarray) -> Optional[Tuple[Tuple[int, int], float, float, float]]:
        """Detect elliptical plate (for angled shots).
        
        Works when plate is viewed from an angle and appears as an ellipse.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Tuple of (center (x, y), major_axis, minor_axis, angle) or None if not found
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            
            # Apply blur to reduce noise
            blurred = cv2.GaussianBlur(gray, (5, 5), 0)
            
            # Edge detection
            edges = cv2.Canny(blurred, self.canny_low, self.canny_high)
            
            # Dilate edges to close gaps
            kernel = np.ones((3, 3), np.uint8)
            edges = cv2.dilate(edges, kernel, iterations=1)
            
            # Find contours
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Filter contours by size
            img_height, img_width = image.shape[:2]
            min_area = (img_width * self.min_radius_ratio) ** 2
            max_area = (img_width * self.max_radius_ratio * 2) ** 2
            
            for contour in contours:
                area = cv2.contourArea(contour)
                if area < min_area or area > max_area:
                    continue
                
                # Fit ellipse to contour (need at least 5 points)
                if len(contour) >= 5:
                    ellipse = cv2.fitEllipse(contour)
                    center, axes, angle = ellipse
                    major_axis = max(axes)
                    minor_axis = min(axes)
                    
                    # Check if it's roughly elliptical (plate-like)
                    aspect_ratio = major_axis / minor_axis if minor_axis > 0 else 1
                    if aspect_ratio < self.ellipse_aspect_ratio_max:
                        logger.info(f"Detected elliptical plate: center={center}, "
                                  f"major={major_axis:.1f}, minor={minor_axis:.1f}, "
                                  f"aspect_ratio={aspect_ratio:.2f}")
                        return (int(center[0]), int(center[1])), float(major_axis), float(minor_axis), float(angle)
            
            return None
            
        except Exception as e:
            logger.warning(f"Ellipse detection failed: {e}")
            return None
    
    def detect_plate_contour(self, image: np.ndarray) -> Optional[Tuple[np.ndarray, float]]:
        """Detect plate using contour analysis and shape matching.
        
        Alternative method that finds the largest circular/elliptical contour.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Tuple of (contour_points, diameter_pixels) or None if not found
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            
            # Apply adaptive threshold to handle varying lighting
            binary = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                cv2.THRESH_BINARY_INV, 11, 2
            )
            
            # Morphological operations to clean up
            kernel = np.ones((5, 5), np.uint8)
            binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
            binary = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
            
            # Find contours
            contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Find contour with largest area that's roughly circular
            best_contour = None
            best_circularity = 0
            img_height, img_width = image.shape[:2]
            
            for contour in contours:
                area = cv2.contourArea(contour)
                perimeter = cv2.arcLength(contour, True)
                
                if perimeter == 0:
                    continue
                
                # Calculate circularity: 4π * area / perimeter²
                # Perfect circle = 1.0
                circularity = 4 * np.pi * area / (perimeter * perimeter)
                
                # Check size (between 20% and 45% of image width)
                approx_radius = np.sqrt(area / np.pi)
                if (approx_radius > img_width * self.min_radius_ratio and 
                    approx_radius < img_width * self.max_radius_ratio and
                    circularity > 0.7):  # Good circularity threshold
                    
                    if circularity > best_circularity:
                        best_circularity = circularity
                        best_contour = contour
            
            if best_contour is not None:
                # Calculate diameter from bounding circle
                (x, y), radius = cv2.minEnclosingCircle(best_contour)
                diameter_pixels = radius * 2
                logger.info(f"Detected plate via contour: diameter={diameter_pixels:.1f}px, "
                          f"circularity={best_circularity:.3f}")
                return best_contour, diameter_pixels
            
            return None
            
        except Exception as e:
            logger.warning(f"Contour detection failed: {e}")
            return None
    
    def get_plate_diameter_pixels(self, image: np.ndarray) -> Optional[float]:
        """Get plate diameter in pixels using multiple methods.
        
        Tries multiple detection methods in order of reliability.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Plate diameter in pixels, or None if no plate detected
        """
        # Method 1: Circle detection (best for top-down shots)
        circle_result = self.detect_plate_circle(image)
        if circle_result:
            center, radius = circle_result
            return radius * 2
        
        # Method 2: Ellipse detection (good for angled shots)
        ellipse_result = self.detect_plate_ellipse(image)
        if ellipse_result:
            center, major_axis, minor_axis, angle = ellipse_result
            # Average of major and minor axes as diameter approximation
            return (major_axis + minor_axis) / 2
        
        # Method 3: Contour analysis (fallback)
        contour_result = self.detect_plate_contour(image)
        if contour_result:
            contour, diameter = contour_result
            return diameter
        
        logger.warning("No plate detected with any method")
        return None
    
    def get_plate_mask(self, image: np.ndarray) -> Optional[np.ndarray]:
        """Create a binary mask of the detected plate.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            Binary mask where 255 = plate, 0 = background, or None if no plate
        """
        diameter_pixels = self.get_plate_diameter_pixels(image)
        
        if diameter_pixels is None:
            return None
        
        mask = np.zeros(image.shape[:2], dtype=np.uint8)
        
        # Try circle detection first for mask
        circle_result = self.detect_plate_circle(image)
        if circle_result:
            center, radius = circle_result
            cv2.circle(mask, center, int(radius), 255, -1)
            return mask
        
        # Try ellipse detection
        ellipse_result = self.detect_plate_ellipse(image)
        if ellipse_result:
            center, major_axis, minor_axis, angle = ellipse_result
            axes = (int(major_axis / 2), int(minor_axis / 2))
            cv2.ellipse(mask, center, axes, angle, 0, 360, 255, -1)
            return mask
        
        # Try contour-based mask
        contour_result = self.detect_plate_contour(image)
        if contour_result:
            contour, diameter = contour_result
            cv2.drawContours(mask, [contour], -1, 255, -1)
            return mask
        
        return None
    
    def get_plate_center(self, image: np.ndarray) -> Optional[Tuple[int, int]]:
        """Get the center coordinates of the detected plate.
        
        Args:
            image: RGB image as numpy array
            
        Returns:
            (x, y) center coordinates, or None if no plate detected
        """
        # Try circle detection
        circle_result = self.detect_plate_circle(image)
        if circle_result:
            center, radius = circle_result
            return center
        
        # Try ellipse detection
        ellipse_result = self.detect_plate_ellipse(image)
        if ellipse_result:
            center, major_axis, minor_axis, angle = ellipse_result
            return center
        
        # Try contour detection
        contour_result = self.detect_plate_contour(image)
        if contour_result:
            contour, diameter = contour_result
            # Calculate center from contour moments
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
                return (cx, cy)
        
        return None