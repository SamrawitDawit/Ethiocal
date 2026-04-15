# ============================================
# EthioCal — Meal Routes
# ============================================
# POST /                  — create meal with food items
# POST /{id}/ingredients  — add ingredients to meal (optional)
# GET  /                  — user's meal history
# GET  /{id}              — get single meal
# DELETE /{id}            — delete a meal
# ============================================

from fastapi import APIRouter, Depends, HTTPException, Query, Header, status
from app.core.dependencies import get_current_user
from app.db.supabase import get_supabase_admin
from app.schemas.meal import (
    MealCreate,
    MealCreateResponse,
    MealAddIngredients,
    MealAddIngredientsResponse,
    MealResponse,
)
from app.services.daily_summary_service import DailySummaryService
from datetime import datetime
import traceback

router = APIRouter()

VALID_MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}


@router.post("/", response_model=MealCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_meal(
    payload: MealCreate,
    current_user: dict = Depends(get_current_user),
):
    """Create a new meal with selected food items.

    Step 1 of meal logging - select the foods you ate.
    """
    if payload.meal_type not in VALID_MEAL_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"meal_type must be one of {VALID_MEAL_TYPES}.",
        )

    if not payload.food_items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one food item is required.",
        )

    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Fetch all food items in one query
    food_ids = [item.food_item_id for item in payload.food_items]
    food_result = (
        supabase.table("food_items")
        .select("*")
        .in_("id", food_ids)
        .execute()
    )

    food_map = {f["id"]: f for f in food_result.data}

    # Validate all food items exist
    missing = [fid for fid in food_ids if fid not in food_map]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Food items not found: {missing}",
        )

    # Calculate total calories
    total_calories = 0.0
    for item in payload.food_items:
        food = food_map[item.food_item_id]
        total_calories += item.quantity * food["standard_serving_size"] / 100.0 * food["calories_per_100g"]

    # Create the meal
    meal_result = (
        supabase.table("meals")
        .insert({
            "user_id": user_id,
            "meal_type": payload.meal_type,
            "portion_size": payload.portion_size,
            "total_calories": total_calories,
        })
        .execute()
    )
    meal = meal_result.data[0]

    # Create meal food items
    food_items_response = []
    for item in payload.food_items:
        food = food_map[item.food_item_id]
        item_calories = item.quantity * food["standard_serving_size"] / 100.0 * food["calories_per_100g"]

        item_result = (
            supabase.table("meal_food_items")
            .insert({
                "meal_id": meal["id"],
                "food_item_id": item.food_item_id,
                "quantity": item.quantity,
                "total_calories": item_calories,
            })
            .execute()
        )

        item_data = item_result.data[0]
        item_data["food_item"] = food
        food_items_response.append(item_data)

    # Update daily summary
    await DailySummaryService.update_daily_summary(
        user_id=user_id,
        meal_date=datetime.now().date(),
        operation="upsert"
    )

    return MealCreateResponse(
        id=meal["id"],
        user_id=meal["user_id"],
        meal_type=meal["meal_type"],
        portion_size=meal["portion_size"],
        total_calories=total_calories,
        food_items=food_items_response,
        created_at=meal["created_at"],
    )


@router.post("/{meal_id}/ingredients", response_model=MealAddIngredientsResponse)
async def add_ingredients_to_meal(
    meal_id: str,
    payload: MealAddIngredients,
    current_user: dict = Depends(get_current_user),
):
    """Add cooking ingredients to an existing meal (optional).

    Step 2 of meal logging - optionally specify cooking ingredients.

    Ingredient adjustment logic:
    - If the ingredient is a standard ingredient for any food item in the meal,
      only the DIFFERENCE (user quantity - standard quantity) affects calories.
    - If it's a new ingredient (not in standard), the full calorie value is added.
    """
    if not payload.ingredients:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one ingredient is required.",
        )

    supabase = get_supabase_admin()
    user_id = current_user["id"]

    # Verify meal exists and belongs to user
    meal_result = (
        supabase.table("meals")
        .select("*")
        .eq("id", meal_id)
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )

    if not meal_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found.",
        )

    meal = meal_result.data

    # Fetch all ingredients
    ingredient_ids = [ing.ingredient_id for ing in payload.ingredients]
    ing_result = (
        supabase.table("ingredients")
        .select("*")
        .in_("id", ingredient_ids)
        .execute()
    )

    ing_map = {i["id"]: i for i in ing_result.data}

    # Validate all ingredients exist
    missing = [iid for iid in ingredient_ids if iid not in ing_map]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Ingredients not found: {missing}",
        )

    # Get food items in this meal
    meal_food_items_result = (
        supabase.table("meal_food_items")
        .select("food_item_id, quantity")
        .eq("meal_id", meal_id)
        .execute()
    )

    food_item_ids = [fi["food_item_id"] for fi in meal_food_items_result.data]
    food_item_quantities = {fi["food_item_id"]: fi["quantity"] for fi in meal_food_items_result.data}

    # Get standard ingredients for all food items in this meal
    standard_ingredients = {}
    if food_item_ids:
        std_ing_result = (
            supabase.table("food_item_ingredients")
            .select("*")
            .in_("food_item_id", food_item_ids)
            .execute()
        )

        # Aggregate standard quantities per ingredient
        # If same ingredient is standard for multiple food items, sum them up
        for std in std_ing_result.data:
            ing_id = std["ingredient_id"]
            food_qty = food_item_quantities.get(std["food_item_id"], 1.0)
            # Standard quantity is scaled by how many servings of the food
            std_qty = std["quantity_grams"] * food_qty
            if ing_id in standard_ingredients:
                standard_ingredients[ing_id] += std_qty
            else:
                standard_ingredients[ing_id] = std_qty

    # Add ingredients and calculate calories with adjustment
    added_calories = 0.0
    ingredients_response = []

    for ing in payload.ingredients:
        ingredient = ing_map[ing.ingredient_id]
        user_quantity = ing.quantity
        standard_qty = standard_ingredients.get(ing.ingredient_id, 0.0)

        # Calculate the difference - only extra/less from standard affects calories
        quantity_difference = user_quantity - standard_qty

        # Calories are based on the difference, which can be negative (used less than standard)
        ing_calories = quantity_difference / 100.0 * ingredient["calories_per_100g"]
        added_calories += ing_calories

        ing_insert_result = (
            supabase.table("meal_ingredients")
            .insert({
                "meal_id": meal_id,
                "ingredient_id": ing.ingredient_id,
                "quantity": user_quantity,
                "total_calories": ing_calories,
            })
            .execute()
        )

        ing_data = ing_insert_result.data[0]
        ing_data["ingredient"] = ingredient
        ingredients_response.append(ing_data)

    # Update meal total calories
    new_total = meal["total_calories"] + added_calories
    supabase.table("meals").update({"total_calories": new_total}).eq("id", meal_id).execute()

    # Update daily summary
    await DailySummaryService.update_daily_summary(
        user_id=user_id,
        meal_date=datetime.fromisoformat(meal["created_at"]).date(),
        operation="upsert"
    )

    return MealAddIngredientsResponse(
        meal_id=meal_id,
        ingredients=ingredients_response,
        added_calories=added_calories,
        new_total_calories=new_total,
    )


@router.get("/", response_model=list[MealResponse])
async def get_meal_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    date: str = Query(None, description="Date in YYYY-MM-DD format (optional)"),
    current_user: dict = Depends(get_current_user),
):
    """Return the current user's meal history (newest first)."""
    supabase = get_supabase_admin()

    # Build query
    query = (
        supabase.table("meals")
        .select("*")
        .eq("user_id", current_user["id"])
    )

    # Add date filtering if provided
    if date:
        query_date = datetime.strptime(date, '%Y-%m-%d')
        start_datetime = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_datetime = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        query = query.gte("created_at", start_datetime.isoformat()).lte("created_at", end_datetime.isoformat())

    # Get meals
    meals_result = (
        query
        .order("created_at", desc=True)
        .range(skip, skip + limit - 1)
        .execute()
    )

    meals = []
    for meal in meals_result.data:
        # Get food items for this meal
        food_items_result = (
            supabase.table("meal_food_items")
            .select("*, food_item:food_items(*)")
            .eq("meal_id", meal["id"])
            .execute()
        )

        # Get ingredients for this meal
        ingredients_result = (
            supabase.table("meal_ingredients")
            .select("*, ingredient:ingredients(*)")
            .eq("meal_id", meal["id"])
            .execute()
        )

        meal["food_items"] = food_items_result.data
        meal["ingredients"] = ingredients_result.data
        meals.append(meal)

    return meals


@router.get("/meal-food-items")
async def get_meal_food_items_by_date(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    """Get all meal food items for a specific date."""
    try:
        print("=" * 50)
        print("Endpoint reached")
        
        # Check if current_user exists
        if not current_user:
            print("ERROR: current_user is None")
            return {"meal_food_items": [], "error": "No user found"}
        
        print(f"current_user type: {type(current_user)}")
        print(f"current_user keys: {current_user.keys() if isinstance(current_user, dict) else 'Not a dict'}")
        
        # Safely get user_id
        user_id = None
        if isinstance(current_user, dict):
            user_id = current_user.get("user_id") or current_user.get("id")
        
        print(f"Using user_id: {user_id}")
        print(f"Date requested: {date}")
        
        if not user_id:
            print("ERROR: No user_id found in current_user")
            return {"meal_food_items": [], "error": "No user_id in token"}
        
        # Initialize Supabase
        print("Initializing Supabase...")
        supabase = get_supabase_admin()
        
        # Parse date range
        query_date = datetime.strptime(date, '%Y-%m-%d')
        start_datetime = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_datetime = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        print(f"Date range: {start_datetime} to {end_datetime}")
        
        # Get meals - use try-except for the query
        try:
            print("Executing meals query...")
            meals_result = (
                supabase.table("meals")
                .select("id")
                .eq("user_id", user_id)
                .gte("created_at", start_datetime.isoformat())
                .lte("created_at", end_datetime.isoformat())
                .execute()
            )
            print(f"Meals query successful. Result: {meals_result.data}")
        except Exception as e:
            print(f"Meals query failed: {str(e)}")
            return {"meal_food_items": [], "error": f"Meals query failed: {str(e)}"}
        
        if not meals_result.data:
            print("No meals found for this user/date")
            return {"meal_food_items": []}
        
        meal_ids = [meal["id"] for meal in meals_result.data]
        print(f"Meal IDs: {meal_ids}")
        
        # Get meal_food_items
        try:
            print("Executing meal_food_items query...")
            result = (
                supabase.table("meal_food_items")
                .select("*")
                .in_("meal_id", meal_ids)
                .execute()
            )
            print(f"Found {len(result.data) if result.data else 0} items")
        except Exception as e:
            print(f"meal_food_items query failed: {str(e)}")
            return {"meal_food_items": [], "error": f"Items query failed: {str(e)}"}
        
        print("=" * 50)
        return {"meal_food_items": result.data if result.data else []}
        
    except Exception as e:
        print(f"UNEXPECTED ERROR: {str(e)}")
        print(traceback.format_exc())
        return {"meal_food_items": [], "error": f"Unexpected error: {str(e)}"}


@router.get("/daily-nutrients")
async def get_daily_nutrients(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    current_user: dict = Depends(get_current_user)
):
    """Get total nutrient breakdown (protein, carbs, fat) for a specific date."""
    try:
        print(f"\n=== get_daily_nutrients called ===")
        print(f"Date: {date}")
        print(f"User: {current_user.get('id')}")
        
        supabase = get_supabase_admin()
        user_id = current_user["id"]
        
        # Parse date range
        query_date = datetime.strptime(date, '%Y-%m-%d')
        start_datetime = query_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_datetime = query_date.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        print(f"Date range: {start_datetime} to {end_datetime}")
        
        # Get meals for the date
        meals_result = (
            supabase.table("meals")
            .select("id, total_calories")
            .eq("user_id", user_id)
            .gte("created_at", start_datetime.isoformat())
            .lte("created_at", end_datetime.isoformat())
            .execute()
        )
        
        print(f"Meals found: {len(meals_result.data) if meals_result.data else 0}")
        
        # Calculate totals from meals directly
        total_calories = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0
        meal_count = 0
        
        if meals_result.data:
            meal_count = len(meals_result.data)
            
            # Sum calories from meals
            for meal in meals_result.data:
                total_calories += meal.get("total_calories", 0)
            
            # Get all meal IDs
            meal_ids = [meal["id"] for meal in meals_result.data]
            
            # Get food items for these meals
            try:
                food_items_result = (
                    supabase.table("meal_food_items")
                    .select("""
                        quantity,
                        total_calories,
                        food_item:food_items (
                            protein,
                            carbohydrates,
                            fat,
                            calories_per_100g
                        )
                    """)
                    .in_("meal_id", meal_ids)
                    .execute()
                )
                
                print(f"Food items found: {len(food_items_result.data) if food_items_result.data else 0}")
                
                # Calculate nutrient totals
                for item in (food_items_result.data or []):
                    quantity = item.get("quantity", 1)
                    food_item = item.get("food_item")
                    
                    if food_item:
                        # Calculate based on quantity and standard serving size
                        # Assuming standard_serving_size is 100g if not specified
                        serving_multiplier = quantity
                        
                        total_protein += (food_item.get("protein", 0) * serving_multiplier)
                        total_carbs += (food_item.get("carbohydrates", 0) * serving_multiplier)
                        total_fat += (food_item.get("fat", 0) * serving_multiplier)
                        
            except Exception as e:
                print(f"Error getting food items: {e}")
                # Continue with just calorie totals
        
        response_data = {
            "date": date,
            "total_protein": round(total_protein, 1),
            "total_carbohydrates": round(total_carbs, 1),
            "total_fat": round(total_fat, 1),
            "total_calories": round(total_calories, 1),
            "meal_count": meal_count
        }
        
        print(f"Response: {response_data}")
        print("=== get_daily_nutrients completed ===\n")
        
        return response_data
        
    except Exception as e:
        print(f"ERROR in get_daily_nutrients: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get daily nutrients: {str(e)}"
        )
    
@router.get("/{meal_id}", response_model=MealResponse)
async def get_meal(
    meal_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get a single meal by ID."""
    supabase = get_supabase_admin()

    meal_result = (
        supabase.table("meals")
        .select("*")
        .eq("id", meal_id)
        .eq("user_id", current_user["id"])
        .maybe_single()
        .execute()
    )

    if not meal_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found.",
        )

    meal = meal_result.data

    # Get food items
    food_items_result = (
        supabase.table("meal_food_items")
        .select("*, food_item:food_items(*)")
        .eq("meal_id", meal_id)
        .execute()
    )

    # Get ingredients
    ingredients_result = (
        supabase.table("meal_ingredients")
        .select("*, ingredient:ingredients(*)")
        .eq("meal_id", meal_id)
        .execute()
    )

    meal["food_items"] = food_items_result.data
    meal["ingredients"] = ingredients_result.data

    return meal

@router.delete("/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meal(
    meal_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Delete a meal."""
    supabase = get_supabase_admin()

    # Verify meal exists and belongs to user
    meal_result = (
        supabase.table("meals")
        .select("id")
        .eq("id", meal_id)
        .eq("user_id", current_user["id"])
        .maybe_single()
        .execute()
    )

    if not meal_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Meal not found.",
        )

    # Get meal date for summary update
    meal_date = datetime.fromisoformat(meal_result.data["created_at"]).date()
    user_id = current_user["id"]

    # Delete cascades to meal_food_items and meal_ingredients
    supabase.table("meals").delete().eq("id", meal_id).execute()

    # Update daily summary
    await DailySummaryService.update_daily_summary(
        user_id=user_id,
        meal_date=meal_date,
        operation="upsert"
    )