-- ============================================================
-- Job Description Analysis
-- Purpose: Store structured analysis results extracted from JD text
-- ============================================================

create table if not exists rb_job_description (
  jd_id            bigserial primary key,
  content_hash     text not null unique,           -- sha256: dedup
  raw_text         text not null,                  -- original JD text
  required_skills  jsonb not null default '[]',    -- ["java", "spring-boot", ...]
  preferred_skills jsonb not null default '[]',    -- ["kubernetes", ...]
  min_years_exp    integer,                        -- null if not mentioned
  level            text,                           -- 'junior' | 'mid' | 'senior' | null
  summary          text,                           -- one-sentence role summary
  model_name       text not null,                  -- e.g. gpt-4o-mini
  created_at       timestamptz not null default now()
);

create index if not exists idx_jd_level
  on rb_job_description(level) where level is not null;

create index if not exists idx_jd_created
  on rb_job_description(created_at desc);
