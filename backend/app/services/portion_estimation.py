import logging

logger = logging.getLogger(__name__)

# Single fallback density (g/cm³) when no density is available in the database
# Most foods are close to water density (1.0 g/cm³)
FALLBACK_DENSITY_G_PER_CM3 = 0.8


def calculate_calories(
    portion_grams: float,
    calories_per_100g: float,
) -> float:
    """Calculate calories based on portion size."""
    calories = (portion_grams / 100.0) * calories_per_100g
    return round(calories, 1)


def estimate_portion_and_calories(
    label: str,
    mask_area: float | None,
    image_width: int,
    image_height: int,
    calories_per_100g: float | None,
    standard_serving_size: float | None = None,
    relative_height: float | None = None,
    pixel_area: int | None = None,
    density_g_per_cm3: float | None = None,
    volume_cm3: float | None = None,
) -> dict:
    """Estimate portion size using volume × density.
    
    Args:
        label: Food label from AI model
        mask_area: Area of the segmentation mask (unused)
        image_width: Width of the image in pixels (unused)
        image_height: Height of the image in pixels (unused)
        calories_per_100g: Calories per 100g from database
        standard_serving_size: Standard serving size (unused)
        relative_height: Relative height from depth detection
        pixel_area: Pixel area from depth detection
        density_g_per_cm3: Density from database (can be None)
        volume_cm3: Pre-calculated volume from depth estimator

    Returns:
        Dict with portion_grams, estimated_calories, and estimation_method
    """
    portion_grams = None
    estimation_method = "none"
    
    # Use pre-calculated volume from depth estimator
    if volume_cm3 is not None and volume_cm3 > 0:
        # Get density: use database value if available, otherwise fallback
        if density_g_per_cm3 is not None and density_g_per_cm3 > 0:
            density = density_g_per_cm3
            logger.info(f"Using database density for {label}: {density} g/cm³")
        else:
            density = FALLBACK_DENSITY_G_PER_CM3
            logger.warning(f"No density found for {label}, using fallback: {density} g/cm³")
        
        # Mass (grams) = Volume (cm³) × Density (g/cm³)
        portion_grams = volume_cm3 * density
        estimation_method = "volume_x_density"
        
        logger.info(
            f"Portion estimation for {label}: "
            f"volume={volume_cm3:.1f}cm³ × "
            f"density={density:.2f}g/cm³ = "
            f"{portion_grams:.1f}g"
        )
    
    # Fallback if no volume data available
    else:
        logger.error(f"Cannot estimate portion for {label}: No volume data available")
        portion_grams = None
        estimation_method = "failed_no_volume"

    # Calculate calories if we have portion size and nutritional data
    estimated_calories = None
    if portion_grams is not None and portion_grams > 0:
        if calories_per_100g is not None and calories_per_100g > 0:
            estimated_calories = calculate_calories(portion_grams, calories_per_100g)
            logger.info(f"Calories for {label}: {portion_grams}g = {estimated_calories} cal")
        else:
            logger.warning(f"No calorie data for {label}")

    return {
        "portion_grams": round(portion_grams, 1) if portion_grams else None,
        "estimated_calories": estimated_calories,
        "estimation_method": estimation_method,
    }