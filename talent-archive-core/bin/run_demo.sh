#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# 4-box Resume/JD analysis demo (stub framework)
#
# Box 1: Extract    -> find raw hits in text (simple substring rules)
# Box 2: Normalize  -> map to canonical labels and enforce baseline dictionary
# Box 3: Tagging    -> group labels into hard/soft tags
# Box 4: Match      -> compare resume tags vs JD tags, compute missing + score
#
# Output:
# - Inserts RESUME and JD into rb.rb_document
# - Inserts one run into rb.rb_analysis_run with result_json
# - Prints a single JSON line: {"runId":..., "result":{...}}
# ------------------------------------------------------------

# Database connection (port 55434 is the current working port)
DB_URL="${DB_URL:-postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db}"

# Baseline dictionary version (we seeded baseline_set_id = 1)
BASELINE_SET_ID="${BASELINE_SET_ID:-1}"

# Default demo texts (you can override by passing 2 args)
DEFAULT_RESUME="Skilled in Python3; 3 years experience; Bachelor's degree; familiar with Docker and Linux; can write SQL."
DEFAULT_JD="Role: Backend Engineer. Requirements: Python and Java; 3-5 years; Bachelor's degree; strong SQL and Linux."

RESUME_TEXT="${1:-$DEFAULT_RESUME}"
JD_TEXT="${2:-$DEFAULT_JD}"

# We generate a temporary SQL file to avoid shell escaping issues
SQL_FILE="$(mktemp /tmp/rb_demo.XXXXXX.sql)"

python3 - <<'PY' "$SQL_FILE" "$RESUME_TEXT" "$JD_TEXT" "$BASELINE_SET_ID"
import sys, random, string

sql_path, resume_text, jd_text, baseline_set_id = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

# Generate a unique dollar-quote tag so we can safely embed arbitrary text into SQL
tag = "RB" + "".join(random.choice(string.ascii_letters + string.digits) for _ in range(10))

def dq(s: str) -> str:
    return f"${tag}$" + s + f"${tag}$"

with open(sql_path, "w", encoding="utf-8") as f:
    f.write(f"""
\\set ON_ERROR_STOP on
set search_path to rb, public;

with
-- Insert input documents first
ins_resume as (
  insert into rb_document(doc_type, raw_text, lang, source)
  values ('RESUME', {dq(resume_text)}, 'en', 'demo')
  returning id, raw_text
),
ins_jd as (
  insert into rb_document(doc_type, raw_text, lang, source)
  values ('JD', {dq(jd_text)}, 'en', 'demo')
  returning id, raw_text
),

-- =========================
-- Box 1: Extract (stub)
-- Rule A: if any alias (rb_alias_map.alias) appears in text -> extract canonical
-- =========================
resume_alias_hits as (
  select distinct m.canonical
  from rb_alias_map m, ins_resume r
  where m.baseline_set_id = {baseline_set_id}
    and m.status = 'active'
    and position(m.alias in r.raw_text) > 0
),
jd_alias_hits as (
  select distinct m.canonical
  from rb_alias_map m, ins_jd j
  where m.baseline_set_id = {baseline_set_id}
    and m.status = 'active'
    and position(m.alias in j.raw_text) > 0
),

-- Rule B: for skill/* terms, also allow direct match by the "tail" token (e.g., skill/python -> match "python")
resume_skill_tail_hits as (
  select distinct t.canonical
  from rb_baseline_term t, ins_resume r
  where t.baseline_set_id = {baseline_set_id}
    and t.status = 'active'
    and t.canonical like 'skill/%'
    and position(lower(split_part(t.canonical,'/',2)) in lower(r.raw_text)) > 0
),
jd_skill_tail_hits as (
  select distinct t.canonical
  from rb_baseline_term t, ins_jd j
  where t.baseline_set_id = {baseline_set_id}
    and t.status = 'active'
    and t.canonical like 'skill/%'
    and position(lower(split_part(t.canonical,'/',2)) in lower(j.raw_text)) > 0
),

-- =========================
-- Box 2: Normalize (core)
-- Enforce: final tags must exist in rb_baseline_term, otherwise drop them.
-- =========================
resume_norm as (
  select distinct h.canonical
  from (
    select canonical from resume_alias_hits
    union
    select canonical from resume_skill_tail_hits
  ) h
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = h.canonical
),
jd_norm as (
  select distinct h.canonical
  from (
    select canonical from jd_alias_hits
    union
    select canonical from jd_skill_tail_hits
  ) h
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = h.canonical
),

-- =========================
-- Box 3: Tagging (stub)
-- Hard tags: degree/* and exp/*
-- Soft tags: skill/*
-- =========================
resume_hard as (
  select canonical from resume_norm
  where split_part(canonical,'/',1) in ('degree','exp')
),
resume_soft as (
  select canonical from resume_norm
  where split_part(canonical,'/',1) = 'skill'
),
jd_hard as (
  select canonical from jd_norm
  where split_part(canonical,'/',1) in ('degree','exp')
),
jd_soft as (
  select canonical from jd_norm
  where split_part(canonical,'/',1) = 'skill'
),

-- =========================
-- Box 4: Match (stub)
-- matched = intersection(resume_norm, jd_norm)
-- missing = jd_norm - resume_norm
-- score = round(100 * matched_count / jd_count)
-- =========================
matched as (
  select canonical from resume_norm
  intersect
  select canonical from jd_norm
),
missing as (
  select canonical from jd_norm
  except
  select canonical from resume_norm
),

agg as (
  select
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from resume_norm) as resume_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from jd_norm) as jd_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from resume_hard) as resume_hard_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from resume_soft) as resume_soft_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from jd_hard) as jd_hard_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from jd_soft) as jd_soft_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from matched) as matched_tags,
    (select coalesce(jsonb_agg(canonical order by canonical), '[]'::jsonb) from missing) as missing_tags,
    (select count(*) from matched) as matched_count,
    (select count(*) from jd_norm) as jd_count
),

result as (
  select jsonb_build_object(
    'baselineSetId', {baseline_set_id},
    'resumeTags', resume_tags,
    'jdTags', jd_tags,
    'resumeHardTags', resume_hard_tags,
    'resumeSoftTags', resume_soft_tags,
    'jdHardTags', jd_hard_tags,
    'jdSoftTags', jd_soft_tags,
    'matchedTags', matched_tags,
    'missingTags', missing_tags,
    'score', case when jd_count=0 then 0 else round(100.0 * matched_count / jd_count) end
  ) as result_json
  from agg
),

ins_run as (
  insert into rb_analysis_run(baseline_set_id, resume_document_id, jd_document_id, result_json)
  select {baseline_set_id}, r.id, j.id, res.result_json
  from ins_resume r
  cross join ins_jd j
  cross join result res
  returning id, result_json
)

select jsonb_build_object('runId', id, 'result', result_json)::text
from ins_run;
""")
PY

# Execute SQL and print the single JSON line
psql "$DB_URL" -X -q -t -A -f "$SQL_FILE"

rm -f "$SQL_FILE"
