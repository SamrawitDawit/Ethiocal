from fastapi import APIRouter, HTTPException
from models.calorie_calculation import CalorieRequest
from services.calorie_calculation import NutritionService

router = APIRouter()


@router.post("/calculate-calories")
async def calculate_calories(request: CalorieRequest):

    try:
        result = NutritionService.calculate_calories(request.foods)
        return result

    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))