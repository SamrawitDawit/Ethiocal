-- =============================================
-- EthioCal — Migration 001: Schema Updates
-- =============================================
-- Run this SQL in Supabase SQL Editor to apply
-- all schema changes.
--
-- Changes:
-- 1. Add extended profile fields to profiles table
-- 2. Drop user_profiles table
-- 3. Create food_item_ingredients table
-- =============================================


-- =============================================
-- 1. Add extended profile fields to profiles
-- =============================================
-- These fields were previously in user_profiles table.
-- Now consolidated into the profiles table.
-- =============================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS age integer CHECK (age > 0 OR age IS NULL),
  ADD COLUMN IF NOT EXISTS gender text CHECK (gender IN ('Male', 'Female') OR gender IS NULL),
  ADD COLUMN IF NOT EXISTS height float CHECK (height > 0 OR height IS NULL),
  ADD COLUMN IF NOT EXISTS weight float CHECK (weight > 0 OR weight IS NULL),
  ADD COLUMN IF NOT EXISTS activity_level text CHECK (activity_level IN ('Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active') OR activity_level IS NULL),
  ADD COLUMN IF NOT EXISTS daily_calorie_goal float DEFAULT 2000.0;


-- =============================================
-- 2. Migrate data from user_profiles (if exists)
-- =============================================
-- Transfer existing data before dropping the table.
-- =============================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_profiles') THEN
    UPDATE public.profiles p
    SET
      age = up.age,
      gender = up.gender,
      height = up.height,
      weight = up.weight,
      activity_level = up.activity_level,
      daily_calorie_goal = COALESCE(up.daily_calorie_goal, 2000.0)
    FROM public.user_profiles up
    WHERE p.id = up.user_id;
  END IF;
END $$;


-- =============================================
-- 3. Drop user_profiles table
-- =============================================

DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.food_composition CASCADE;


-- =============================================
-- 4. Create food_item_ingredients table
-- =============================================
-- Links food items to their standard ingredients
-- with the standard quantity used in preparation.
-- =============================================

CREATE TABLE IF NOT EXISTS public.food_item_ingredients (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    food_item_id    uuid NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
    ingredient_id   uuid NOT NULL REFERENCES public.ingredients(id) ON DELETE CASCADE,
    standard_quantity float NOT NULL DEFAULT 1.0,
    created_at      timestamptz DEFAULT now(),
    UNIQUE(food_item_id, ingredient_id)
);

CREATE INDEX IF NOT EXISTS idx_food_item_ingredients_food_id
  ON public.food_item_ingredients(food_item_id);

ALTER TABLE public.food_item_ingredients ENABLE ROW LEVEL SECURITY;

-- Drop policies if they exist (to make migration idempotent)
DROP POLICY IF EXISTS "Authenticated users can read food item ingredients" ON public.food_item_ingredients;
DROP POLICY IF EXISTS "Admins can manage food item ingredients" ON public.food_item_ingredients;

CREATE POLICY "Authenticated users can read food item ingredients"
    ON public.food_item_ingredients FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admins can manage food item ingredients"
    ON public.food_item_ingredients FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );


-- =============================================
-- 5. Seed sample food item ingredients
-- =============================================
-- Example: Doro Wot typically contains these
-- standard ingredients.
-- =============================================

-- Note: You'll need to run these INSERT statements
-- after getting the actual UUIDs from your database.
-- This is a template showing the structure:

-- INSERT INTO public.food_item_ingredients (food_item_id, ingredient_id, standard_quantity)
-- SELECT f.id, i.id, 2.0  -- 2 servings of ingredient
-- FROM public.food_items f, public.ingredients i
-- WHERE f.ai_label = 'doro_wot' AND i.name = 'Niter Kibbeh'
-- ON CONFLICT DO NOTHING;

-- INSERT INTO public.food_item_ingredients (food_item_id, ingredient_id, standard_quantity)
-- SELECT f.id, i.id, 3.0  -- 3 servings of onion
-- FROM public.food_items f, public.ingredients i
-- WHERE f.ai_label = 'doro_wot' AND i.name = 'Onion'
-- ON CONFLICT DO NOTHING;

-- INSERT INTO public.food_item_ingredients (food_item_id, ingredient_id, standard_quantity)
-- SELECT f.id, i.id, 2.0  -- 2 servings of berbere
-- FROM public.food_items f, public.ingredients i
-- WHERE f.ai_label = 'doro_wot' AND i.name = 'Berbere'
-- ON CONFLICT DO NOTHING;


-- =============================================
-- Migration complete!
-- =============================================
