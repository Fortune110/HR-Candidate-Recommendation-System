-- Usage:
-- psql "$DB_URL" -v source=video_interview_v1 -f sql/rank_behavior_by_source.sql

select tag, count(*) as cnt
from candidate_archive_event e
cross join lateral jsonb_array_elements_text(e.archive_json->'behavior_tags') as tag
where e.source = :'source'
group by tag
order by cnt desc;
