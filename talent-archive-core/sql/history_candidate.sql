-- Usage:
-- psql "$DB_URL" -v candidate_id=101 -f sql/history_candidate.sql

select
  event_id,
  candidate_id,
  source,
  model,
  generated_at,
  created_at
from candidate_archive_event
where candidate_id = :'candidate_id'
order by event_id desc;
