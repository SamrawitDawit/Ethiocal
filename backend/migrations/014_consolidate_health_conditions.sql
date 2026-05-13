-- =============================================
-- EthioCal - Migration 014: Consolidate health data
-- =============================================
-- This migration assumes `user_health_conditions` is already the canonical
-- store for a user's health conditions. It only adds per-condition metadata
-- support and removes legacy duplicate columns from `profiles` if they exist.

ALTER TABLE public.user_health_conditions
  ADD COLUMN IF NOT EXISTS condition_metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS has_diabetes,
  DROP COLUMN IF EXISTS has_hypertension,
  DROP COLUMN IF EXISTS has_high_cholesterol,
  DROP COLUMN IF EXISTS diabetes_type,
  DROP COLUMN IF EXISTS latest_hba1c;