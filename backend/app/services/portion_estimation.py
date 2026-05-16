import logging

logger = logging.getLogger(__name__)


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
    estimated_grams: float | None = None,
    area_ratio: float | None = None,
) -> dict:
    """Estimate portion size using heuristic estimation from vision engine.

    Args:
        label: Food label from AI model
        mask_area: Area of the segmentation mask (unused in heuristic approach)
        image_width: Width of the image in pixels (unused in heuristic approach)
        image_height: Height of the image in pixels (unused in heuristic approach)
        calories_per_100g: Calories per 100g from database
        standard_serving_size: Standard serving size (unused in heuristic approach)
        relative_height: Relative height from depth detection (unused in heuristic approach)
        pixel_area: Pixel area from depth detection (unused in heuristic approach)
        density_g_per_cm3: Density from database (unused in heuristic approach)
        volume_cm3: Pre-calculated voxel volume (unused in heuristic approach)
        estimated_grams: Pre-calculated grams from heuristic estimation in vision engine
        area_ratio: Area ratio from vision engine (for logging)

    Returns:
        Dict with portion_grams, estimated_calories, and estimation_method
    """
    portion_grams = None
    estimation_method = "none"

    # Use pre-calculated grams from heuristic estimation in vision engine
    if estimated_grams is not None and estimated_grams > 0:
        portion_grams = estimated_grams
        estimation_method = "heuristic"

        logger.info(
            f"Portion estimation for {label}: "
            f"grams={portion_grams:.1f}g (from heuristic estimation, area_ratio={area_ratio:.4f})"
        )

    # Fallback if no heuristic data available
    else:
        logger.error(f"Cannot estimate portion for {label}: No heuristic estimation data available")
        portion_grams = None
        estimation_method = "failed_no_heuristic_data"

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