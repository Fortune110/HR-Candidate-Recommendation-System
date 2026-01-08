insert into candidates(candidate_id, name)
values (:'candidate_id', null)
on conflict (candidate_id) do nothing;

insert into candidate_archive_event(
  candidate_id,
  source,
  model,
  generated_at,
  archive_json
)
values (
  :'candidate_id',
  coalesce(
    nullif((:'archive_json'::jsonb #>> '{_meta,source}'), ''),
    nullif(:'ai_source', '')
  ),
  coalesce(
    nullif((:'archive_json'::jsonb #>> '{_meta,model}'), ''),
    nullif(:'ai_model', '')
  ),
  (:'archive_json'::jsonb #>> '{_meta,generated_at}')::timestamptz,
  :'archive_json'::jsonb
);

insert into candidate_archive(candidate_id, archive_json, updated_at)
values (
  :'candidate_id',
  :'archive_json'::jsonb,
  now()
)
on conflict (candidate_id) do update
set archive_json = excluded.archive_json,
    updated_at = now();
