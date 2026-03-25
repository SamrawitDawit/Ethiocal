# ============================================
# EthioCal — Portion Estimation Service
# ============================================
# Hybrid portion pipeline :
# 1) Plate-guide geometry, 2) Relative-area split,
# 3) Average serving-size fallback.
# ============================================

import math

from app.schemas.food import (
    FoodRegionInput,
    PlateGuideInput,
    PortionEstimateItem,
    PortionFoodProfile,
    PortionEstimateResponse,
    PortionEstimationRequest,
)

DEFAULT_DENSITY_G_PER_CM3 = 1.00
DEFAULT_BBOX_FILL_RATIO = 0.72
DEFAULT_MEAL_MASS_G = 600.0

PLATE_SIZE_CM = {
    "circle": 35.0,
    "oval": (36.0, 30.0),
    "rectangle": (35.0, 28.0),
}


def _resolve_density(food: PortionFoodProfile) -> float:
    density = food.density_g_per_cm3 or DEFAULT_DENSITY_G_PER_CM3
    return max(density, 0.1)


def _resolve_thickness_cm(food: PortionFoodProfile, region: FoodRegionInput) -> float:
    if region.avg_thickness_cm_override is not None:
        thickness_cm = region.avg_thickness_cm_override
    else:
        thickness_cm = food.avg_thickness_cm

    if thickness_cm is None:
        raise ValueError(
            f"avg_thickness_cm is missing for food_item_id={food.id}. "
            "Set thickness in DB or provide avg_thickness_cm_override."
        )

    return max(thickness_cm, 0.01)


def _resolve_region_area_px(region: FoodRegionInput) -> float:
    fill_ratio = region.fill_ratio if region.fill_ratio is not None else DEFAULT_BBOX_FILL_RATIO
    area_px = (
        region.mask_area_px
        if region.mask_area_px is not None
        else region.bbox_width_px * region.bbox_height_px * fill_ratio
    )
    return max(area_px, 1.0)


def _plate_real_area_cm2(plate_guide: PlateGuideInput) -> float:
    if plate_guide.shape == "circle":
        diameter = PLATE_SIZE_CM["circle"]
        radius = diameter / 2.0
        return math.pi * radius * radius

    if plate_guide.shape == "oval":
        major, minor = PLATE_SIZE_CM["oval"]
        return math.pi * (major / 2.0) * (minor / 2.0)

    if plate_guide.shape == "rectangle":
        width, height = PLATE_SIZE_CM["rectangle"]
        return width * height

    raise ValueError(f"Unsupported plate guide shape: {plate_guide.shape}")


def _estimate_geometry_with_plate_guide(
    payload: PortionEstimationRequest,
    food_by_id: dict[str, PortionFoodProfile],
) -> PortionEstimateResponse:
    plate_guide = payload.plate_guide
    if plate_guide is None:
        raise ValueError("plate_guide is required for geometry estimation.")

    if plate_guide.plate_mask_area_px <= 0:
        raise ValueError("plate_mask_area_px must be > 0.")

    scale_cm2_per_px = _plate_real_area_cm2(plate_guide) / plate_guide.plate_mask_area_px

    items: list[PortionEstimateItem] = []
    total_mass_g = 0.0

    for region in payload.foods:
        food = food_by_id[region.food_item_id]
        area_cm2 = _resolve_region_area_px(region) * scale_cm2_per_px
        thickness_cm = _resolve_thickness_cm(food, region)
        density = _resolve_density(food)

        volume_cm3 = area_cm2 * thickness_cm
        mass_g = volume_cm3 * density
        total_mass_g += mass_g

        items.append(
            PortionEstimateItem(
                food_item_id=region.food_item_id,
                estimated_mass_g=round(mass_g, 2),
            )
        )

    return PortionEstimateResponse(
        items=items,
        total_estimated_mass_g=round(total_mass_g, 2),
        estimation_method="geometry_plate_guide",
    )


def _estimate_relative_area(
    payload: PortionEstimationRequest,
) -> PortionEstimateResponse:
    items: list[PortionEstimateItem] = []
    areas_by_food: list[tuple[str, float]] = []

    for region in payload.foods:
        areas_by_food.append((region.food_item_id, _resolve_region_area_px(region)))

    total_area_px = sum(area for _, area in areas_by_food)
    if total_area_px <= 0:
        raise ValueError("Unable to compute relative-area split: total food area is zero.")

    total_mass_g = 0.0
    for food_item_id, area_px in areas_by_food:
        ratio = area_px / total_area_px
        mass_g = ratio * DEFAULT_MEAL_MASS_G
        total_mass_g += mass_g
        items.append(
            PortionEstimateItem(
                food_item_id=food_item_id,
                estimated_mass_g=round(mass_g, 2),
            )
        )

    return PortionEstimateResponse(
        items=items,
        total_estimated_mass_g=round(total_mass_g, 2),
        estimation_method="relative_area_default_meal_mass",
    )


def _estimate_average_serving(
    payload: PortionEstimationRequest,
    food_by_id: dict[str, PortionFoodProfile],
) -> PortionEstimateResponse:
    items: list[PortionEstimateItem] = []
    total_mass_g = 0.0

    for region in payload.foods:
        food = food_by_id[region.food_item_id]
        if food.serving_size_g is None:
            raise ValueError(
                f"serving_size_g is missing for food_item_id={food.id}. "
                "Set serving_size_g in DB to enable fallback estimation."
            )

        mass_g = max(food.serving_size_g, 1.0)
        total_mass_g += mass_g
        items.append(
            PortionEstimateItem(
                food_item_id=region.food_item_id,
                estimated_mass_g=round(mass_g, 2),
            )
        )

    return PortionEstimateResponse(
        items=items,
        total_estimated_mass_g=round(total_mass_g, 2),
        estimation_method="average_serving_size",
    )


def estimate_portions(
    payload: PortionEstimationRequest,
    food_by_id: dict[str, PortionFoodProfile],
) -> PortionEstimateResponse:
    """Estimate portions with a robust hybrid decision flow."""
    if payload.use_plate_guide:
        if payload.plate_guide is None:
            raise ValueError("use_plate_guide=true requires plate_guide metadata.")
        return _estimate_geometry_with_plate_guide(payload, food_by_id)

    if len(payload.foods) > 1:
        return _estimate_relative_area(payload)

    return _estimate_average_serving(payload, food_by_id)
