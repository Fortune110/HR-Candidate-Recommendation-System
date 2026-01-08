-- demo data
insert into candidates(name) values ('Alex') returning candidate_id;
insert into candidate_archive(candidate_id, archive_json)
values (
  1,
  '{
    "behavior_tags": ["calm","structured","detail_oriented"],
    "skill_tags": ["Java","Spring Boot"],
    "risk_tags": ["minor_inconsistency"]
  }'::jsonb
);

insert into candidates(name) values ('Bella') returning candidate_id;
insert into candidate_archive(candidate_id, archive_json)
values (
  2,
  '{
    "behavior_tags": ["structured","structured","calm"],
    "skill_tags": ["Python"],
    "risk_tags": []
  }'::jsonb
);

insert into candidates(name) values ('Chris') returning candidate_id;
insert into candidate_archive(candidate_id, archive_json)
values (
  3,
  '{
    "behavior_tags": ["calm","assertive"],
    "skill_tags": ["Go"],
    "risk_tags": ["vague_answer"]
  }'::jsonb
);

-- ranking query: behavior tags
select tag, count(*) as cnt
from candidate_archive a
cross join lateral jsonb_array_elements_text(a.archive_json->'behavior_tags') as tag
group by tag
order by cnt desc;
