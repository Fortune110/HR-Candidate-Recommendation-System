create table if not exists rb_document (
  document_id bigserial primary key,
  entity_type text not null,         -- candidate_resume
  entity_id text not null,           -- candidateId
  content_hash text not null,        -- sha256:...
  content_text text not null,
  created_at timestamptz not null default now(),
  unique(entity_type, entity_id, content_hash)
);

create table if not exists rb_run (
  run_id bigserial primary key,
  document_id bigint not null references rb_document(document_id),
  analyzer text not null,            -- openai_responses / local_model ...
  analyzer_version text not null,    -- v1
  model_name text,
  prompt_version text not null,      -- bootstrap_v1 / baseline_v1
  config jsonb not null default '{}'::jsonb,
  status text not null default 'success',
  created_at timestamptz not null default now()
);

create table if not exists rb_canonical_tag (
  canonical_tag_id bigserial primary key,
  framework text not null,           -- INTERNAL / ESCO / SFIA ...
  canonical_id text not null,        -- normalized id
  label text not null,               -- display
  tag_type text not null default 'keyword',
  extra jsonb,
  updated_at timestamptz not null default now(),
  unique(framework, canonical_id)
);

create table if not exists rb_extracted_tag (
  extracted_tag_id bigserial primary key,
  run_id bigint not null references rb_run(run_id),
  canonical_tag_id bigint not null references rb_canonical_tag(canonical_tag_id),
  score numeric(6,4) not null default 0.5000,
  weight numeric(6,4) not null default 1.0,
  created_at timestamptz not null default now()
);

create index if not exists idx_rb_extracted_tag_run on rb_extracted_tag(run_id);

create table if not exists rb_tag_evidence (
  evidence_id bigserial primary key,
  extracted_tag_id bigint not null references rb_extracted_tag(extracted_tag_id),
  evidence_text text not null
);
