-- Migration: Add streak tracking to profiles table
-- This adds current streak and best streak columns for leaderboard functionality

-- Add streak columns to profiles table
ALTER TABLE profiles 
ADD COLUMN current_streak INTEGER DEFAULT 0,
ADD COLUMN best_streak INTEGER DEFAULT 0,
ADD COLUMN last_meal_date DATE;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_profiles_current_streak ON profiles(current_streak);
CREATE INDEX IF NOT EXISTS idx_profiles_best_streak ON profiles(best_streak);

-- Add comments for documentation
COMMENT ON COLUMN profiles.current_streak IS 'Current consecutive days with logged meals';
COMMENT ON COLUMN profiles.best_streak IS 'Best streak achieved by user';
COMMENT ON COLUMN profiles.last_meal_date IS 'Date of last logged meal (for streak calculation)';

-- Initialize existing profiles with current streak based on their meal history
UPDATE profiles 
SET 
    current_streak = COALESCE(streak_data.meal_count, 0),
    best_streak = GREATEST(COALESCE(profiles.best_streak, 0), COALESCE(streak_data.meal_count, 0)),
    last_meal_date = streak_data.last_meal_date
FROM (
    SELECT 
        p.id,
        COUNT(DISTINCT DATE(m.created_at)) as meal_count,
        MAX(DATE(m.created_at)) as last_meal_date
    FROM profiles p
    LEFT JOIN meals m ON p.id = m.user_id 
    AND m.created_at >= CURRENT_DATE - INTERVAL '30 days'
    WHERE p.id IN (SELECT id FROM profiles WHERE current_streak = 0 OR best_streak = 0)
    GROUP BY p.id
) AS streak_data
WHERE profiles.id = streak_data.id;
