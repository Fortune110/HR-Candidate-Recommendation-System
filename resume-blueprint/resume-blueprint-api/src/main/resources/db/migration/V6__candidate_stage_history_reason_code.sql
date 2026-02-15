-- ============================================================
-- Add reason_code and job_id to candidate_stage_history
-- Purpose: Support result feedback for training data collection
-- ============================================================

-- Add reason_code field for stage change reasons
-- Examples: TECH_MISMATCH, SALARY, CANDIDATE_DECLINED, HC_FROZEN, NO_SHOW, OTHER
alter table rb_candidate_stage_history
  add column if not exists reason_code varchar(64) null;

-- Add job_id field to track which job/position this stage change relates to
-- Note: This is a denormalized field for training data collection
alter table rb_candidate_stage_history
  add column if not exists job_id bigint null;

-- Index for reason_code queries (analytics on rejection reasons, etc.)
create index if not exists idx_candidate_stage_history_reason_code
  on rb_candidate_stage_history(reason_code)
  where reason_code is not null;

-- Index for job_id queries (stage changes by job)
create index if not exists idx_candidate_stage_history_job_id
  on rb_candidate_stage_history(job_id)
  where job_id is not null;
