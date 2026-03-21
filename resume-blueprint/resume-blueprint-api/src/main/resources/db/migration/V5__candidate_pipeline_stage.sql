-- ============================================================
-- Candidate Pipeline Stage Management
-- Purpose: Track candidate interview process stages and history
-- ============================================================

-- ------------------------------------------------------------
-- Candidate: Core candidate table with pipeline stage
-- Note: candidate_id is string (matches rb_document.entity_id)
-- ------------------------------------------------------------
create table if not exists rb_candidate (
  candidate_id text primary key,            -- matches rb_document.entity_id
  stage text not null default 'new',        -- pipeline stage enum
  stage_updated_at timestamptz,             -- last stage change time
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for stage filtering and queries
create index if not exists idx_candidate_stage 
  on rb_candidate(stage) where stage is not null;

create index if not exists idx_candidate_updated 
  on rb_candidate(stage_updated_at desc) where stage_updated_at is not null;

-- ------------------------------------------------------------
-- Candidate Stage History: Audit trail of all stage changes
-- ------------------------------------------------------------
create table if not exists rb_candidate_stage_history (
  history_id bigserial primary key,
  candidate_id text not null references rb_candidate(candidate_id) on delete cascade,
  from_stage text not null,                 -- previous stage
  to_stage text not null,                   -- new stage
  changed_by text not null,                 -- operator/user ID
  note text,                                -- optional note
  changed_at timestamptz not null default now(),
  -- Prevent duplicate history entries (idempotency)
  unique(candidate_id, to_stage, changed_at, changed_by)
);

-- Index for candidate history queries (most common: get history for a candidate)
create index if not exists idx_candidate_stage_history_candidate 
  on rb_candidate_stage_history(candidate_id, changed_at desc);

-- Index for stage change queries (analytics)
create index if not exists idx_candidate_stage_history_stage 
  on rb_candidate_stage_history(from_stage, to_stage, changed_at);

-- Index for changed_by queries (audit)
create index if not exists idx_candidate_stage_history_changed_by 
  on rb_candidate_stage_history(changed_by, changed_at desc);

-- ------------------------------------------------------------
-- Optional: Job/Candidate association (if job_id exists in system)
-- This is a placeholder for future extension
-- ------------------------------------------------------------
-- create table if not exists rb_candidate_job (
--   candidate_id text not null references rb_candidate(candidate_id) on delete cascade,
--   job_id text,                            -- if system has job postings
--   jd_id bigint,                           -- if linked to JD analysis
--   created_at timestamptz not null default now(),
--   primary key (candidate_id, job_id)
-- );
