-- Migration: Create daily_summaries table for optimized dashboard performance
-- This table stores pre-calculated daily nutritional summaries to replace
-- multiple expensive API calls with a single fast lookup

CREATE TABLE IF NOT EXISTS daily_summaries (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_calories INTEGER DEFAULT 0,
    total_protein DECIMAL(10,2) DEFAULT 0.0,
    total_carbohydrates DECIMAL(10,2) DEFAULT 0.0,
    total_fat DECIMAL(10,2) DEFAULT 0.0,
    breakfast_calories INTEGER DEFAULT 0,
    lunch_calories INTEGER DEFAULT 0,
    dinner_calories INTEGER DEFAULT 0,
    snack_calories INTEGER DEFAULT 0,
    meal_count INTEGER DEFAULT 0,
    daily_calorie_goal INTEGER DEFAULT 2000,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure each user has only one summary per date
    UNIQUE(user_id, date)
);

-- Create indexes for optimal performance
CREATE INDEX IF NOT EXISTS idx_daily_summaries_user_date ON daily_summaries(user_id, date);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_date ON daily_summaries(date);

-- Add trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_daily_summary_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER daily_summaries_updated_at
    BEFORE UPDATE ON daily_summaries
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_summary_updated_at();

-- Add comments for documentation
COMMENT ON TABLE daily_summaries IS 'Pre-calculated daily nutritional summaries for dashboard optimization';
COMMENT ON COLUMN daily_summaries.total_calories IS 'Total calories consumed for the day';
COMMENT ON COLUMN daily_summaries.total_protein IS 'Total protein in grams for the day';
COMMENT ON COLUMN daily_summaries.total_carbohydrates IS 'Total carbohydrates in grams for the day';
COMMENT ON COLUMN daily_summaries.total_fat IS 'Total fat in grams for the day';
COMMENT ON COLUMN daily_summaries.breakfast_calories IS 'Calories from breakfast meals';
COMMENT ON COLUMN daily_summaries.lunch_calories IS 'Calories from lunch meals';
COMMENT ON COLUMN daily_summaries.dinner_calories IS 'Calories from dinner meals';
COMMENT ON COLUMN daily_summaries.snack_calories IS 'Calories from snack meals';
COMMENT ON COLUMN daily_summaries.meal_count IS 'Number of meals logged for the day';
COMMENT ON COLUMN daily_summaries.daily_calorie_goal IS 'User daily calorie goal for the day';
