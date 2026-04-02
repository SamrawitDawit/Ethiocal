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

import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query, status

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
)
from app.services.food_recognition import predict_food

router = APIRouter()


@router.post("/recognize", response_model=FoodRecognitionResponse)
async def recognize_food(
    image: UploadFile = File(...),
    # current_user: dict = Depends(get_current_user),  # TODO: re-enable auth after testing
):
    """Upload a food image and get AI-powered recognition results.

    Steps:
      1. Validate the uploaded file is an image and within size limits.
      2. Upload the file to Supabase Storage.
      3. Send bytes to the AI model service.
      4. Match predicted labels to food_items records in the database.
      5. Return predictions with nutritional data.
    """
    # --- Validate file type ---
    if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG, and WebP images are accepted.",
        )

    # --- Read & validate size ---
    contents = await image.read()
    max_bytes = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image exceeds {settings.MAX_IMAGE_SIZE_MB} MB limit.",
        )

    # --- Upload to Supabase Storage ---
    ext = image.filename.rsplit(".", 1)[-1] if image.filename else "jpg"
    #filename = f"{current_user['id']}/{uuid.uuid4()}.{ext}"  # TODO: use current_user['id'] after re-enabling auth
    filename = f"anonymous/{uuid.uuid4()}.{ext}"  # TODO: use current_user['id'] after re-enabling auth

    supabase = get_supabase_admin()
    supabase.storage.from_(settings.STORAGE_BUCKET).upload(
        path=filename,
        file=contents,
        file_options={"content-type": image.content_type},
    )

    # Build the public URL for the stored image
    image_url = supabase.storage.from_(settings.STORAGE_BUCKET).get_public_url(filename)

    # --- AI prediction ---
    predictions, image_width, image_height = await predict_food(contents, filename)

    # --- Match labels to food items in DB ---
    results: list[FoodRecognitionResult] = []
    for pred in predictions:
        label = pred["label"]
        confidence = pred["confidence"]

        # Try to match label to food item in DB (optional - may not exist)
        food_item = None
        try:
            result = (
                supabase.table("food_items")
                .select("*")
                .eq("ai_label", label)
                .maybe_single()
                .execute()
            )
            if result and result.data:
                food_item = FoodItemResponse(**result.data)
        except Exception:
            # DB lookup failed - continue without food_item data
            pass

        # Build bounding box from prediction
        bbox = None
        if pred.get("bounding_box"):
            bbox = BoundingBox(**pred["bounding_box"])

        # Build mask from prediction
        mask = None
        if pred.get("mask"):
            mask = SegmentationMask(**pred["mask"])

        results.append(
            FoodRecognitionResult(
                label=label,
                confidence=confidence,
                bounding_box=bbox,
                mask=mask,
                food_item=food_item,
            )
        )

    return FoodRecognitionResponse(
        predictions=results,
        image_url=image_url,
        image_width=image_width,
        image_height=image_height,
    )


@router.get("/", response_model=list[FoodItemResponse])
async def list_food_items(
    search: str | None = Query(None, description="Filter food items by name"),
    current_user: dict = Depends(get_current_user),
):
    """List all food items, optionally filtered by name search."""
    supabase = get_supabase_admin()
    query = supabase.table("food_items").select("*").order("name")

    if search:
        query = query.ilike("name", f"%{search}%")

    result = query.execute()
    return result.data


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

    return result.data
