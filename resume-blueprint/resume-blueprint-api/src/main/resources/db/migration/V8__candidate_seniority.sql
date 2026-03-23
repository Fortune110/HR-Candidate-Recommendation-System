-- ============================================================
-- V8: Add experience_years and seniority_level to rb_candidate
-- ============================================================

ALTER TABLE rb_candidate ADD COLUMN IF NOT EXISTS experience_years INTEGER;
ALTER TABLE rb_candidate ADD COLUMN IF NOT EXISTS seniority_level VARCHAR(10);

-- Backfill existing records: null experience_years → Junior
UPDATE rb_candidate
SET seniority_level = 'Junior'
WHERE seniority_level IS NULL;
