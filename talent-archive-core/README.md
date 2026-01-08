# Talent Archive Core

Phase 1 of a larger Talent AI project series.

## What it does
A minimal candidate archive database that stores AI-processed candidate profiles (JSONB)
and supports fast tag aggregation (e.g., behavior tag ranking).

## Scope (Phase 1)
- Store candidate identity (candidates)
- Store AI-processed archives (candidate_archive.archive_json)
- Aggregate & rank tags via SQL

## Out of scope
- ATS workflow / job applications
- AI inference pipeline
- File storage details (resume/video storage)

## Tech
- PostgreSQL (JSONB + GIN index)
- Docker Compose

## Run locally
Start DB:
  docker compose up -d

Initialize schema:
  psql "postgresql://archive_user:archive_pass@localhost:55433/talent_archive" -f init.sql

Load demo data + run ranking query:
  psql "postgresql://archive_user:archive_pass@localhost:55433/talent_archive" -f seed.sql

## Ranking SQL (behavior tags)
select tag, count(*) as cnt
from candidate_archive a
cross join lateral jsonb_array_elements_text(a.archive_json->'behavior_tags') as tag
group by tag
order by cnt desc;

## Ranking queries (callable SQL)
Predefined ranking queries you can run directly:

- Behavior tags:
  psql "postgresql://archive_user:archive_pass@localhost:55433/talent_archive" -f sql/rank_behavior.sql

- Skill tags:
  psql "postgresql://archive_user:archive_pass@localhost:55433/talent_archive" -f sql/rank_skill.sql

- Risk tags:
  psql "postgresql://archive_user:archive_pass@localhost:55433/talent_archive" -f sql/rank_risk.sql

## Quick run
You can run rankings via a helper script:

- ./bin/rank.sh behavior
- ./bin/rank.sh skill
- ./bin/rank.sh risk

## Ingest external AI outputs
This repo supports ingesting AI-processed JSON into the candidate archive (upsert).

Example:
- ./bin/ingest.sh 3 samples/ai_archive_4.json

After ingest, rankings update immediately:
- ./bin/rank.sh behavior
- ./bin/rank.sh skill
- ./bin/rank.sh risk
