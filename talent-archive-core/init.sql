create table if not exists candidates (
  candidate_id bigserial primary key,
  name text,
  created_at timestamptz not null default now()
);

create table if not exists candidate_archive (
  candidate_id bigint primary key references candidates(candidate_id) on delete cascade,
  archive_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists idx_archive_json_gin
on candidate_archive using gin (archive_json);
