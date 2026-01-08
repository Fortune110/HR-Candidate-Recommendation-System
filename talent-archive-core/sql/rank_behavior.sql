select tag, count(*) as cnt
from candidate_archive a
cross join lateral jsonb_array_elements_text(a.archive_json->'behavior_tags') as tag
group by tag
order by cnt desc;
