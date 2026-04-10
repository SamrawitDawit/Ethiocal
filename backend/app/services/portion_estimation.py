# ============================================
# EthioCal — Portion Size Estimation Service
# ============================================
# Maps detected food labels to standard portion
# sizes in grams and calculates calories.
# ============================================

import logging

logger = logging.getLogger(__name__)

# Standard portion sizes in grams for each detected food
PORTION_SIZES: dict[str, float] = {
    # Main dishes
    "injera": 150.0,
    "doro_wat": 200.0,
    "doro_wot": 200.0,
    "siga_wat": 200.0,
    "siga_wot": 200.0,
    "kitfo": 150.0,
    "tibs": 180.0,
    "shiro": 200.0,
    "misir_wat": 200.0,
    "misir_wot": 200.0,
    "gomen": 150.0,
    "ayib": 80.0,
    "firfir": 250.0,
    "ful": 180.0,
    "fatira": 200.0,
    "genfo": 250.0,
    "chechebsa": 200.0,
    "kategna": 120.0,

    # Default for unknown foods
    "default": 150.0,
}


def normalize_label(label: str) -> str:
    """Normalize food label for lookup."""
    return label.lower().strip().replace(" ", "_").replace("-", "_")


def get_portion_size(label: str) -> float:
    """Get the standard portion size in grams for a food label."""
    normalized = normalize_label(label)
    return PORTION_SIZES.get(normalized, PORTION_SIZES["default"])


def calculate_calories(
    portion_grams: float,
    calories_per_100g: float,
) -> float:
    """Calculate calories based on portion size.

    Args:
        portion_grams: Portion size in grams
        calories_per_100g: Calories per 100 grams of the food

    Returns:
        Estimated calories for the portion
    """
    calories = (portion_grams / 100.0) * calories_per_100g
    return round(calories, 1)


def estimate_portion_and_calories(
    label: str,
    mask_area: float | None,
    image_width: int,
    image_height: int,
    calories_per_100g: float | None,
    standard_serving_size: float | None = None,
) -> dict:
    """Estimate portion size and calculate calories.

    Args:
        label: Food label from AI model
        mask_area: Area of the segmentation mask (unused, for compatibility)
        image_width: Width of the image in pixels (unused, for compatibility)
        image_height: Height of the image in pixels (unused, for compatibility)
        calories_per_100g: Calories per 100g (from DB)
        standard_serving_size: Standard serving size (unused, for compatibility)

    Returns:
        Dict with portion_grams, estimated_calories, and estimation_method
    """
    # Get standard portion size for the food label
    portion_grams = get_portion_size(label)

    # Calculate calories if we have nutritional data
    estimated_calories = None
    if calories_per_100g is not None:
        estimated_calories = calculate_calories(portion_grams, calories_per_100g)

    logger.info(
        f"Portion estimation for {label}: "
        f"portion_grams={portion_grams:.0f}, "
        f"estimated_calories={estimated_calories}"
    )

    return {
        "portion_grams": portion_grams,
        "estimated_calories": estimated_calories,
        "estimation_method": "standard_serving",
    }

