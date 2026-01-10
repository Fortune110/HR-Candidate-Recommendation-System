-- ============================================================
-- Resume Blueprint (rb) schema
-- Purpose:
--   Provide a stable storage contract for the 4-box framework:
--   1) Extract   (raw fields/hits)
--   2) Normalize (canonical tags enforced by baseline dictionary)
--   3) Tagging   (hard/soft or other grouping)
--   4) Match     (score, missing, matched, evidence)
--
-- Notes:
--   - Keep schema/table names stable; swap implementations later.
--   - This file is idempotent (safe to run multiple times).
-- ============================================================

create schema if not exists rb;

-- Use rb schema by default for subsequent statements.
set search_path to rb, public;

-- ------------------------------------------------------------
-- Baseline dictionary:
-- The system only "recognizes" canonical tags defined here.
-- ------------------------------------------------------------
create table if not exists rb_baseline_term (
  id bigserial primary key,
  baseline_set_id bigint not null,
  canonical text not null,        -- e.g. 'skill/python'
  normalized text not null,       -- typically same as canonical; can be used for stable comparisons
  status text not null default 'active',
  source_note text null,
  created_at timestamptz not null default now()
);

create unique index if not exists ux_rb_baseline_term_set_norm
  on rb_baseline_term(baseline_set_id, normalized);

-- ------------------------------------------------------------
-- Alias mapping:
-- Map many surface forms (alias) to a single canonical tag.
-- alias_normalized is reserved for future normalization rules.
-- ------------------------------------------------------------
create table if not exists rb_alias_map (
  id bigserial primary key,
  baseline_set_id bigint not null,
  alias text not null,            -- raw surface form (e.g. 'Python3', 'bachelor')
  alias_normalized text not null, -- normalized alias (e.g. 'python3', 'bachelor')
  canonical text not null,        -- target canonical tag (must exist in baseline)
  status text not null default 'active',
  source_note text null,
  created_at timestamptz not null default now()
);

create unique index if not exists ux_rb_alias_map_set_aliasnorm
  on rb_alias_map(baseline_set_id, alias_normalized);

-- ------------------------------------------------------------
-- Input documents:
-- Store RESUME / JD raw text for traceability and re-runs.
-- ------------------------------------------------------------
create table if not exists rb_document (
  id bigserial primary key,
  doc_type text not null,         -- 'RESUME' | 'JD'
  raw_text text not null,
  lang text null,                 -- e.g. 'zh' | 'en'
  source text null,               -- e.g. 'demo', 'manual', dataset name
  created_at timestamptz not null default now()
);

create index if not exists ix_rb_document_type_created
  on rb_document(doc_type, created_at desc);

-- ------------------------------------------------------------
-- Analysis runs:
-- Store the final result JSON (tags, score, missing, evidence, etc.)
-- ------------------------------------------------------------
create table if not exists rb_analysis_run (
  id bigserial primary key,
  baseline_set_id bigint not null,
  resume_document_id bigint not null references rb_document(id),
  jd_document_id bigint not null references rb_document(id),
  result_json jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists ix_rb_analysis_run_created
  on rb_analysis_run(created_at desc);
