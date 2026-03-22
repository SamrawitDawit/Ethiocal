from app.db.supabase import get_supabase

class NutritionService:

    @staticmethod
    def calculate_calories(food_items):
        total = {
            "calories": 0,
            "protein": 0,
            "fat": 0,
            "carbs": 0
        }

        breakdown = []

        for item in food_items:

            response = (
                get_supabase()
                .schema("public")
                .table("food_composition")
                .select("food_name_en, energy_kcal, protein, fat, carbohydrate")
                .ilike("food_name_en", f"%{item.name}%")
                .execute()
            )

            if not response.data:
                raise Exception(f"{item.name} not found in database")

            food = response.data[0]

            factor = item.grams / 100

            calories = food["energy_kcal"] * factor
            protein = food["protein"] * factor
            fat = food["fat"] * factor
            carbs = food["carbohydrate"] * factor

            breakdown.append({
                "food": item.name,
                "grams": item.grams,
                "calories": round(calories, 2),
                "protein": round(protein, 2),
                "fat": round(fat, 2),
                "carbs": round(carbs, 2),
            })

            total["calories"] += calories
            total["protein"] += protein
            total["fat"] += fat
            total["carbs"] += carbs

        return {
            "foods": breakdown,
            "total": {k: round(v, 2) for k, v in total.items()}
        }