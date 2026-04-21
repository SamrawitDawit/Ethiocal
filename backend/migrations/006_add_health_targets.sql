-- =============================================
-- EthioCal - Migration 006: Health target fields
-- =============================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS has_diabetes boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_hypertension boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_high_cholesterol boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS diabetes_type text CHECK (diabetes_type IN ('Type 1', 'Type 2') OR diabetes_type IS NULL),
  ADD COLUMN IF NOT EXISTS latest_hba1c float CHECK (latest_hba1c > 0 OR latest_hba1c IS NULL);

ALTER TABLE public.food_items
  ADD COLUMN IF NOT EXISTS saturated_fat_g float DEFAULT 0.0;

ALTER TABLE public.ingredients
  ADD COLUMN IF NOT EXISTS saturated_fat_g float DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS fiber float DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS sodium_mg float DEFAULT 0.0;
