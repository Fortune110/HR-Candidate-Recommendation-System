create table if not exists candidate_archive_event (
  event_id bigserial primary key,
  candidate_id bigint not null references candidates(candidate_id) on delete cascade,
  source text,
  model text,
  generated_at timestamptz,
  archive_json jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_candidate_archive_event_candidate_id
on candidate_archive_event(candidate_id);

create index if not exists idx_candidate_archive_event_archive_json_gin
on candidate_archive_event using gin (archive_json);
