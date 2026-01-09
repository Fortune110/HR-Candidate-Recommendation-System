-- ============================================================
-- Success Profile & Match System
-- Purpose: Compare resume tags with success cohort tags
-- ============================================================

set search_path to rb, public;

-- ------------------------------------------------------------
-- Success Profile: Internal/External success cohort
-- ------------------------------------------------------------
create table if not exists rb_success_profile (
  profile_id bigserial primary key,
  source text not null,                    -- 'internal_employee' | 'external_success'
  role text not null,                       -- e.g. 'Java Backend Engineer'
  level text,                               -- 'junior' | 'mid' | 'senior' | null
  company text,                             -- company name (internal) or industry/region (external)
  raw_text text,                            -- optional: anonymized description
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_success_profile_source_role 
  on rb_success_profile(source, role);

create index if not exists idx_success_profile_source_level 
  on rb_success_profile(source, level) where level is not null;

-- ------------------------------------------------------------
-- Success Profile Tags: Tags extracted from success profiles
-- ------------------------------------------------------------
create table if not exists rb_success_profile_tag (
  tag_id bigserial primary key,
  profile_id bigint not null references rb_success_profile(profile_id) on delete cascade,
  canonical text not null,                 -- e.g. 'skill/java', 'ner/ORG/Google'
  weight numeric(6,4) not null default 1.0, -- frequency/confidence/importance
  evidence text,                             -- snippet that triggered this tag
  via text not null default 'extract',       -- 'skillner' | 'spacy' | 'manual'
  created_at timestamptz not null default now()
);

create index if not exists idx_success_profile_tag_profile 
  on rb_success_profile_tag(profile_id);

create index if not exists idx_success_profile_tag_canonical 
  on rb_success_profile_tag(canonical);

-- ------------------------------------------------------------
-- Resume Project: Extract projects from resume
-- ------------------------------------------------------------
create table if not exists rb_resume_project (
  project_id bigserial primary key,
  resume_document_id bigint not null references rb_document(document_id) on delete cascade,
  project_name text,                        -- extracted project name
  project_text text not null,               -- project description text
  start_date text,                          -- optional: '2020-01' format
  end_date text,                            -- optional: '2023-12' format
  role text,                                -- role in project
  created_at timestamptz not null default now()
);

create index if not exists idx_resume_project_document 
  on rb_resume_project(resume_document_id);

-- ------------------------------------------------------------
-- Resume Project Tags: Tags extracted from each project
-- ------------------------------------------------------------
create table if not exists rb_resume_project_tag (
  tag_id bigserial primary key,
  project_id bigint not null references rb_resume_project(project_id) on delete cascade,
  canonical text not null,
  weight numeric(6,4) not null default 1.0,
  evidence text,
  via text not null default 'extract',
  created_at timestamptz not null default now()
);

create index if not exists idx_resume_project_tag_project 
  on rb_resume_project_tag(project_id);

create index if not exists idx_resume_project_tag_canonical 
  on rb_resume_project_tag(canonical);

-- ------------------------------------------------------------
-- Match Run: Track each matching operation
-- ------------------------------------------------------------
create table if not exists rb_match_run (
  match_run_id bigserial primary key,
  resume_document_id bigint not null references rb_document(document_id),
  target text not null,                     -- 'internal' | 'external' | 'both'
  role_filter text,                         -- optional: filter by role
  level_filter text,                        -- optional: filter by level
  algo_version text not null default 'v1',  -- algorithm version for reproducibility
  config jsonb not null default '{}'::jsonb, -- algorithm parameters
  created_at timestamptz not null default now()
);

create index if not exists idx_match_run_resume 
  on rb_match_run(resume_document_id);

create index if not exists idx_match_run_created 
  on rb_match_run(created_at desc);

-- ------------------------------------------------------------
-- Match Result: Results of matching resume with success profiles
-- ------------------------------------------------------------
create table if not exists rb_match_result (
  result_id bigserial primary key,
  match_run_id bigint not null references rb_match_run(match_run_id) on delete cascade,
  profile_id bigint not null references rb_success_profile(profile_id),
  score numeric(6,4) not null,               -- overall match score (0-1)
  overlap_score numeric(6,4),               -- weighted Jaccard overlap
  gap_penalty numeric(6,4),                  -- penalty for missing high-weight tags
  bonus_score numeric(6,4),                  -- bonus for unique strengths
  overlap_topk jsonb,                       -- top overlapping tags with evidence
  gaps_topk jsonb,                           -- top missing tags (gaps)
  strengths_topk jsonb,                      -- top unique strengths
  explain_json jsonb not null default '{}'::jsonb, -- detailed explanation
  created_at timestamptz not null default now()
);

create index if not exists idx_match_result_run 
  on rb_match_result(match_run_id);

create index if not exists idx_match_result_profile 
  on rb_match_result(profile_id);

create index if not exists idx_match_result_score 
  on rb_match_result(score desc);
