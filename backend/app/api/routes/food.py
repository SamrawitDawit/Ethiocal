# ============================================
# EthioCal — Food Routes
# ============================================
# POST /recognize            — upload image → AI predict
# GET  /                     — list / search food items
# GET  /ingredients          — list all cooking ingredients
# GET  /ingredients/{id}     — get one ingredient by ID
# GET  /{id}/ingredients     — get standard ingredients for a food item
# GET  /{id}                 — get one food item by ID (must be last!)
# ============================================

import re
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query, status

from app.core.config import settings
from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.food import (
    FoodItemResponse,
    IngredientResponse,
    FoodItemIngredientResponse,
    FoodRecognitionResponse,
    FoodRecognitionResult,
    BoundingBox,
    SegmentationMask,
    DepthData,
)
from app.services.enhanced_food_recognition import predict_food_with_depth, predict_food_fallback
from app.services.portion_estimation import estimate_portion_and_calories

router = APIRouter()

logger = logging.getLogger(__name__)

VALID_MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}
DESCRIPTOR_COMMA_PARTS = {
    "black",
    "boiled",
    "brown",
    "dried",
    "drained",
    "dry",
    "flour",
    "fresh",
    "hulled",
    "pearled",
    "peeled",
    "polished",
    "raw",
    "red",
    "refined",
    "salted",
    "split",
    "sweet",
    "unenriched",
    "unfermented",
    "white",
    "whole",
    "whole grain",
    "yellow",
}


def _format_ai_label(label: str | None) -> str | None:
    if not label:
        return None

    parts = [part for part in label.split("_") if part]
    if not parts:
        return None

    return " ".join(part[:1].upper() + part[1:] for part in parts)


def _clean_food_text(value: str | None) -> str | None:
    if not value:
        return None

    cleaned = re.sub(r"\s+", " ", value).strip(" ,;")
    return cleaned or None


def _split_food_text(full_name: str | None) -> tuple[str | None, str | None]:
    cleaned = _clean_food_text(full_name)
    if not cleaned:
        return None, None

    lowered = cleaned.casefold()
    with_index = lowered.find(" with ")
    if with_index > 0:
        return _clean_food_text(cleaned[:with_index]), _clean_food_text(cleaned[with_index:])

    comma_parts = [_clean_food_text(part) for part in cleaned.split(",")]
    comma_parts = [part for part in comma_parts if part]
    if len(comma_parts) >= 3:
        title_parts = [comma_parts[0]]
        if comma_parts[1].casefold() not in DESCRIPTOR_COMMA_PARTS:
            title_parts.append(comma_parts[1])

        title = ", ".join(title_parts)
        remainder = ", ".join(comma_parts[len(title_parts):])
        return _clean_food_text(title), _clean_food_text(remainder)

    word_parts = cleaned.split()
    if len(word_parts) > 4:
        title = " ".join(word_parts[:4])
        remainder = " ".join(word_parts[4:])
        return _clean_food_text(title), _clean_food_text(remainder)

    return cleaned, None


def _normalize_food_item_row(row: dict) -> dict:
    normalized = dict(row)

    full_english = row.get("description_english") or row.get("name")
    inferred_name_english, inferred_description_english = _split_food_text(full_english)

    name_english = _clean_food_text(row.get("name_english")) or inferred_name_english
    if not name_english:
        ai_label = row.get("ai_label")
        if ai_label and not ai_label.startswith("efct_"):
            name_english = _format_ai_label(ai_label)

    normalized["name_english"] = name_english or ""
    normalized["description_english"] = (
        _clean_food_text(row.get("description_english"))
        or inferred_description_english
    )
    normalized["description_amharic"] = _clean_food_text(row.get("description_amharic"))

    return normalized


@router.post("/recognize", response_model=FoodRecognitionResponse)
async def recognize_food(
    image: UploadFile = File(...),
    meal_type: str = Form(default="snack", description="Type of meal: breakfast, lunch, dinner, snack"),
    save_to_history: bool = Form(default=True, description="Whether to save the meal to history"),
    current_user: dict = Depends(get_current_user),
):
    """Upload a food image, get AI-powered recognition, and save to meal history.

    Steps:
      1. Validate the uploaded file is an image and within size limits.
      2. Upload the file to Supabase Storage.
      3. Send bytes to the AI model service.
      4. Match predicted labels to food_items records in the database.
      5. Estimate portion size based on mask area and calculate calories.
      6. Save to meal history if save_to_history is True.
      7. Return predictions with nutritional data.
    """
    logger.info(f"=== START: recognize_food endpoint ===")
    logger.info(f"meal_type={meal_type}, save_to_history={save_to_history}")

    # --- Validate meal_type ---
    logger.info(f"Step 1: Validating meal_type...")
    if meal_type not in VALID_MEAL_TYPES:
        logger.error(f"Invalid meal_type: {meal_type}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid meal_type. Must be one of: {', '.join(VALID_MEAL_TYPES)}",
        )
    logger.info(f"✓ meal_type validated")

    # --- Validate file type ---
    logger.info(f"Step 2: Validating image file type...")
    logger.info(f"  content_type={image.content_type}, filename={image.filename}")
    if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
        logger.error(f"Invalid content_type: {image.content_type}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG, and WebP images are accepted.",
        )
    logger.info(f"✓ File type validated")

    # --- Read & validate size ---
    logger.info(f"Step 3: Reading image bytes...")
    contents = await image.read()
    logger.info(f"  Image size: {len(contents)} bytes")
    max_bytes = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
    if len(contents) > max_bytes:
        logger.error(f"Image size {len(contents)} exceeds limit {max_bytes}")
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds {settings.MAX_IMAGE_SIZE_MB} MB limit.",
        )
    logger.info(f"✓ Image size validated")

    # --- Upload to Supabase Storage ---
    logger.info(f"Step 4: Uploading to Supabase Storage...")
    ext = image.filename.rsplit(".", 1)[-1] if image.filename else "jpg"
    filename = f"{current_user['id']}/{uuid.uuid4()}.{ext}"
    logger.info(f"  Storage path: {filename}")

    supabase = get_supabase_admin()
    supabase.storage.from_(settings.STORAGE_BUCKET).upload(
        path=filename,
        file=contents,
        file_options={"content-type": image.content_type},
    )
    logger.info(f"✓ Uploaded to Supabase")

    # Build the public URL for the stored image
    image_url = supabase.storage.from_(settings.STORAGE_BUCKET).get_public_url(filename)
    logger.info(f"  Image URL: {image_url}")

    # --- AI prediction with depth detection ---
    logger.info(f"Step 5: Starting AI food recognition...")
    logger.info(f"  Attempting enhanced food recognition with depth detection...")
    try:
        logger.info(f"    Calling predict_food_with_depth...")
        predictions, image_width, image_height = await predict_food_with_depth(contents, filename)
        logger.info(f"✓ Enhanced recognition succeeded")
        logger.info(f"  Got {len(predictions)} predictions, image size: {image_width}x{image_height}")
    except Exception as e:
        # Fallback to basic YOLOv8 if depth detection fails
        logger.error(f"✗ Enhanced recognition failed: {type(e).__name__}: {e}", exc_info=True)
        logger.info(f"  Falling back to basic YOLOv8 detection...")
        try:
            predictions, image_width, image_height = await predict_food_fallback(contents, filename)
            logger.info(f"✓ Fallback recognition succeeded")
            logger.info(f"  Got {len(predictions)} predictions")
        except Exception as fallback_error:
            logger.error(f"✗ Fallback recognition also failed: {fallback_error}", exc_info=True)
            raise

    # --- Match labels to food items in DB and estimate portions ---
    logger.info(f"Step 6: Processing predictions and matching to database...")
    results: list[FoodRecognitionResult] = []
    for idx, pred in enumerate(predictions):
        logger.info(f"  Processing prediction {idx+1}/{len(predictions)}")
        label = pred["label"]
        confidence = pred["confidence"]
        logger.info(f"    Label: {label}, Confidence: {confidence}")

        # Try to match label to food item in DB (optional - may not exist)
        food_item = None
        calories_per_100g = None
        standard_serving_size = None
        try:
            logger.info(f"    Looking up food_item with ai_label='{label}'...")
            result = (
                supabase.table("food_items")
                .select("*")
                .eq("ai_label", label)
                .maybe_single()
                .execute()
            )
            if result and result.data:
                normalized_food_item = _normalize_food_item_row(result.data)
                food_item = FoodItemResponse(**normalized_food_item)
                calories_per_100g = result.data.get("calories_per_100g")
                standard_serving_size = result.data.get("standard_serving_size")
                density_g_per_cm3 = result.data.get("density")
                logger.info(f"    ✓ Found food_item: {food_item.name_english}, cals={calories_per_100g}, serving={standard_serving_size}g")
            else:
                logger.info(f"    ✗ No food_item found for label '{label}'")
        except Exception as db_error:
            # DB lookup failed - continue without food_item data
            logger.warning(f"    DB lookup failed: {db_error}")

        # Build bounding box from prediction
        bbox = None
        if pred.get("bounding_box"):
            bbox = BoundingBox(**pred["bounding_box"])
            logger.info(f"    Bounding box: {bbox}")

        # Build mask from prediction
        mask = None
        mask_area = None
        if pred.get("mask"):
            mask = SegmentationMask(**pred["mask"])
            mask_area = pred["mask"].get("area")
            logger.info(f"    Mask area: {mask_area} pixels")

        # Build depth data from prediction
        depth_data = None
        if pred.get("depth_data"):
            depth_data = DepthData(**pred["depth_data"])
            logger.info(f"    Depth data: height={depth_data.height_cm}cm, volume={depth_data.estimated_volume_cm3}cm³")
            print(f"DEBUG HEIGHT -> mean_height_cm: {depth_data.height_cm}")

        # Determine estimation method based on available data
        estimation_method = "mask_area"
        if depth_data and depth_data.estimated_volume_cm3 and depth_data.estimated_volume_cm3 > 0:
            estimation_method = "depth_volume"
            logger.info(f"    Using estimation method: {estimation_method}")

        # Estimate portion size and calculate calories
        logger.info(f"    Estimating portion and calories...")
        volume_cm3 = depth_data.estimated_volume_cm3 if depth_data else None
        portion_data = estimate_portion_and_calories(
            label=label,
            mask_area=mask_area,
            image_width=image_width,
            image_height=image_height,
            calories_per_100g=calories_per_100g,
            standard_serving_size=standard_serving_size,
            relative_height=None,  # No longer used with voxel integration
            pixel_area=depth_data.pixel_area if depth_data else None,
            density_g_per_cm3=density_g_per_cm3,
            volume_cm3=volume_cm3,
        )
        logger.info(f"    ✓ Portion: {portion_data['portion_grams']}g, Calories: {portion_data['estimated_calories']}")

        results.append(
            FoodRecognitionResult(
                label=label,
                confidence=confidence,
                bounding_box=bbox,
                mask=mask,
                depth_data=depth_data,
                food_item=food_item,
                portion_grams=portion_data["portion_grams"],
                estimated_calories=portion_data["estimated_calories"],
                estimation_method=estimation_method,
            )
        )
    logger.info(f"✓ Processed {len(results)} results")

    # --- Save to meal history if requested ---
    logger.info(f"Step 7: Saving to meal history (save_to_history={save_to_history})...")
    meal_id = None
    total_calories = 0.0
    saved_to_history = False

    if save_to_history and results:
        # Calculate total calories
        total_calories = sum(r.estimated_calories for r in results if r.estimated_calories)
        logger.info(f"  Total calories: {total_calories}")

        # Create meal record
        meal_data = {
            "id": str(uuid.uuid4()),
            "user_id": current_user["id"],
            "meal_type": meal_type,
            "portion_size": 1.0,  # For image-based meals
            "total_calories": total_calories,
            "image_url": image_url,
        }
        logger.info(f"  Creating meal record...")

        meal_result = supabase.table("meals").insert(meal_data).execute()
        if meal_result.data:
            meal_id = meal_result.data[0]["id"]
            saved_to_history = True
            logger.info(f"  ✓ Meal saved with id: {meal_id}")

            # Save each food item to meal_food_items
            for result in results:
                if result.food_item and result.estimated_calories and result.portion_grams:
                    logger.info(f"    Saving meal_food_item: {result.food_item.name_english} ({result.portion_grams}g)")
                    # For image-based meals, store portion_grams directly as quantity
                    # Backend meals endpoint will recognize image_url and use:
                    # calories = (quantity / 100) * calories_per_100g
                    meal_food_item_data = {
                        "meal_id": meal_id,
                        "food_item_id": result.food_item.id,
                        "quantity": result.portion_grams,  # Store actual grams, not multiplier
                        "total_calories": result.estimated_calories,
                    }
                    supabase.table("meal_food_items").insert(meal_food_item_data).execute()
                    logger.info(f"    ✓ Saved")
        else:
            logger.warning(f"  ✗ Failed to save meal")
    else:
        logger.info(f"  Skipping meal history save")

    logger.info(f"=== END: recognize_food endpoint (total_calories={total_calories}) ===")
    return FoodRecognitionResponse(
        predictions=results,
        image_url=image_url,
        image_width=image_width,
        image_height=image_height,
        meal_id=meal_id,
        meal_type=meal_type if saved_to_history else None,
        total_calories=total_calories if saved_to_history else None,
        saved_to_history=saved_to_history,
    )


@router.get("/", response_model=list[FoodItemResponse])
async def list_food_items(
    search: str | None = Query(None, description="Filter food items by title or description"),
    current_user: dict = Depends(get_current_user),
):
    """List all food items, optionally filtered by name search."""
    supabase = get_supabase_admin()
    result = supabase.table("food_items").select("*").execute()

    items = [_normalize_food_item_row(row) for row in (result.data or [])]
    if search:
        search_term = search.strip().casefold()
        items = [
            item
            for item in items
            if search_term in (item.get("name_english") or "").casefold()
            or search_term in (item.get("name_amharic") or "").casefold()
            or search_term in (item.get("description_english") or "").casefold()
            or search_term in (item.get("description_amharic") or "").casefold()
        ]

    items.sort(key=lambda item: (item.get("name_english") or "").casefold())
    return items


@router.get("/ingredients", response_model=list[IngredientResponse])
async def list_ingredients(
    search: str | None = Query(None, description="Filter ingredients by name"),
    category: str | None = Query(None, description="Filter by category"),
    current_user: dict = Depends(get_current_user),
):
    """List all cooking ingredients, optionally filtered."""
    supabase = get_supabase_admin()
    query = supabase.table("ingredients").select("*").order("name")

    if search:
        query = query.ilike("name", f"%{search}%")
    if category:
        query = query.eq("category", category)

    result = query.execute()
    return result.data


@router.get("/ingredients/{ingredient_id}", response_model=IngredientResponse)
async def get_ingredient(
    ingredient_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve info for a single ingredient."""
    supabase = get_supabase_admin()
    result = (
        supabase.table("ingredients")
        .select("*")
        .eq("id", ingredient_id)
        .maybe_single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ingredient not found.",
        )

    return result.data


@router.get("/{food_id}/ingredients", response_model=list[FoodItemIngredientResponse])
async def get_food_item_standard_ingredients(
    food_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get the standard ingredients for a food item."""
    supabase = get_supabase_admin()

    # Verify food item exists
    food_result = (
        supabase.table("food_items")
        .select("id")
        .eq("id", food_id)
        .maybe_single()
        .execute()
    )

    if not food_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Food item not found.",
        )

    # Get standard ingredients with ingredient details
    result = (
        supabase.table("food_item_ingredients")
        .select("*, ingredient:ingredients(*)")
        .eq("food_item_id", food_id)
        .execute()
    )

    return result.data


@router.get("/{food_id}", response_model=FoodItemResponse)
async def get_food_item(
    food_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Retrieve nutritional info for a single food item."""
    supabase = get_supabase_admin()
    result = (
        supabase.table("food_items")
        .select("*")
        .eq("id", food_id)
        .maybe_single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Food item not found.",
        )

    return _normalize_food_item_row(result.data)
