create table if not exists document (
  document_id bigserial primary key,
  entity_type text not null,
  entity_id text not null,
  content_hash text not null,
  content_text text not null,
  created_at timestamptz not null default now(),
  unique(entity_type, entity_id, content_hash)
);

create table if not exists analysis_run (
  run_id bigserial primary key,
  document_id bigint not null references document(document_id),
  extractor text not null,
  extractor_version text,
  model_name text,
  config jsonb not null,
  status text not null default 'success',
  created_at timestamptz not null default now()
);

create table if not exists canonical_tag (
  canonical_tag_id bigserial primary key,
  framework text not null,
  canonical_id text not null,
  label text not null,
  tag_type text not null,
  extra jsonb,
  updated_at timestamptz not null default now(),
  unique(framework, canonical_id)
);

create table if not exists extracted_tag (
  extracted_tag_id bigserial primary key,
  run_id bigint not null references analysis_run(run_id),
  canonical_tag_id bigint not null references canonical_tag(canonical_tag_id),
  score numeric(6,4) not null,
  weight numeric(6,4) not null default 1.0,
  created_at timestamptz not null default now()
);

create index if not exists idx_extracted_tag_run on extracted_tag(run_id);

create table if not exists tag_evidence (
  evidence_id bigserial primary key,
  extracted_tag_id bigint not null references extracted_tag(extracted_tag_id),
  evidence_text text not null
);
