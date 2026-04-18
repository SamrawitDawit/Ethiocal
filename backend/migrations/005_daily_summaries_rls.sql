-- Migration: RLS policies for daily_summaries table
-- This ensures users can only access their own daily summary data

-- Enable RLS on daily_summaries table
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own daily summaries
CREATE POLICY "Users can read own daily summaries" ON daily_summaries
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own daily summaries (via API)
CREATE POLICY "Users can insert own daily summaries" ON daily_summaries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own daily summaries (via API)
CREATE POLICY "Users can update own daily summaries" ON daily_summaries
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own daily summaries (via API)
CREATE POLICY "Users can delete own daily summaries" ON daily_summaries
    FOR DELETE USING (auth.uid() = user_id);

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON daily_summaries TO authenticated;
GRANT USAGE ON daily_summaries TO authenticated;

-- Additional: Allow service role (admin) to manage all summaries for maintenance
GRANT ALL ON daily_summaries TO service_role;
