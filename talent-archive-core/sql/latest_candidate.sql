-- Usage:
-- psql "$DB_URL" -v candidate_id=101 -f sql/latest_candidate.sql

select c.candidate_id, c.name, a.updated_at, a.archive_json
from candidates c
join candidate_archive a on a.candidate_id = c.candidate_id
where c.candidate_id = :'candidate_id';
