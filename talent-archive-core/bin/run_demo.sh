#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# 4-box Resume/JD analysis demo (stub framework) + evidence
#
# Box 1: Extract    -> collect raw hits (alias hits + skill tail hits)
# Box 2: Normalize  -> enforce baseline dictionary
# Box 3: Tagging    -> group hard/soft tags
# Box 4: Match      -> matched/missing + score
#
# Evidence:
# - Store which raw substring triggered which canonical tag
# - Keep track of hit source: "alias" or "tail"
# ------------------------------------------------------------

DB_URL="${DB_URL:-postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db}"
BASELINE_SET_ID="${BASELINE_SET_ID:-1}"

DEFAULT_RESUME="Skilled in Python3; 3 years experience; Bachelor's degree; familiar with Docker and Linux; can write SQL."
DEFAULT_JD="Role: Backend Engineer. Requirements: Python and Java; 3-5 years; Bachelor's degree; strong SQL and Linux."

RESUME_TEXT="${1:-$DEFAULT_RESUME}"
JD_TEXT="${2:-$DEFAULT_JD}"

SQL_FILE="$(mktemp /tmp/rb_demo.XXXXXX.sql)"

python3 - <<'PY' "$SQL_FILE" "$RESUME_TEXT" "$JD_TEXT" "$BASELINE_SET_ID"
import sys, random, string

sql_path, resume_text, jd_text, baseline_set_id = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])

tag = "RB" + "".join(random.choice(string.ascii_letters + string.digits) for _ in range(10))
def dq(s: str) -> str:
    return f"${tag}$" + s + f"${tag}$"

with open(sql_path, "w", encoding="utf-8") as f:
    f.write(f"""
\\set ON_ERROR_STOP on
set search_path to rb, public;

with
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
-- Box 1: Extract (stub) + evidence candidates
-- =========================

-- Alias hits (case-insensitive substring)
resume_alias_evidence as (
  select distinct
    m.alias as hit,
    m.canonical,
    'alias'::text as via
  from rb_alias_map m, ins_resume r
  where m.baseline_set_id = {baseline_set_id}
    and m.status = 'active'
    and position(lower(m.alias) in lower(r.raw_text)) > 0
),
jd_alias_evidence as (
  select distinct
    m.alias as hit,
    m.canonical,
    'alias'::text as via
  from rb_alias_map m, ins_jd j
  where m.baseline_set_id = {baseline_set_id}
    and m.status = 'active'
    and position(lower(m.alias) in lower(j.raw_text)) > 0
),

-- Skill tail hits (case-insensitive substring on tail token)
resume_tail_evidence as (
  select distinct
    lower(split_part(t.canonical,'/',2)) as hit,
    t.canonical,
    'tail'::text as via
  from rb_baseline_term t, ins_resume r
  where t.baseline_set_id = {baseline_set_id}
    and t.status = 'active'
    and t.canonical like 'skill/%'
    and position(lower(split_part(t.canonical,'/',2)) in lower(r.raw_text)) > 0
),
jd_tail_evidence as (
  select distinct
    lower(split_part(t.canonical,'/',2)) as hit,
    t.canonical,
    'tail'::text as via
  from rb_baseline_term t, ins_jd j
  where t.baseline_set_id = {baseline_set_id}
    and t.status = 'active'
    and t.canonical like 'skill/%'
    and position(lower(split_part(t.canonical,'/',2)) in lower(j.raw_text)) > 0
),

resume_raw_evidence as (
  select * from resume_alias_evidence
  union
  select * from resume_tail_evidence
),
jd_raw_evidence as (
  select * from jd_alias_evidence
  union
  select * from jd_tail_evidence
),

-- =========================
-- Box 2: Normalize (core)
-- Keep only canonicals that exist in baseline dictionary
-- =========================
resume_norm as (
  select distinct e.canonical
  from resume_raw_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),
jd_norm as (
  select distinct e.canonical
  from jd_raw_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),

-- Evidence after baseline enforcement
resume_evidence as (
  select distinct e.hit, e.canonical, e.via
  from resume_raw_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),
jd_evidence as (
  select distinct e.hit, e.canonical, e.via
  from jd_raw_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),

-- =========================
-- Box 3: Tagging (stub)
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
    (select count(*) from jd_norm) as jd_count,

    (select coalesce(jsonb_agg(jsonb_build_object('hit',hit,'canonical',canonical,'via',via) order by canonical, hit), '[]'::jsonb)
     from resume_evidence) as resume_evidence_json,

    (select coalesce(jsonb_agg(jsonb_build_object('hit',hit,'canonical',canonical,'via',via) order by canonical, hit), '[]'::jsonb)
     from jd_evidence) as jd_evidence_json
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
    'score', case when jd_count=0 then 0 else round(100.0 * matched_count / jd_count) end,
    'evidence', jsonb_build_object(
      'resume', resume_evidence_json,
      'jd', jd_evidence_json
    )
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

psql "$DB_URL" -X -q -t -A -f "$SQL_FILE"

rm -f "$SQL_FILE"
