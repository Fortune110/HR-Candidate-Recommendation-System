#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# 4-box Resume/JD analysis with spaCy + SkillNER extraction
#
# Box 1: Extract    -> spaCy NER + SkillNER (via Python service)
# Box 2: Normalize  -> enforce baseline dictionary
# Box 3: Tagging    -> group hard/soft tags
# Box 4: Match      -> matched/missing + score
#
# Evidence:
# - Store extracted entities with evidence from Python service
# - Keep track of extraction source: "spacy+skillner"
# ------------------------------------------------------------

DB_URL="${DB_URL:-postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db}"
EXTRACT_SERVICE_URL="${EXTRACT_SERVICE_URL:-http://localhost:5000}"
BASELINE_SET_ID="${BASELINE_SET_ID:-1}"

DEFAULT_RESUME="Skilled in Python3; 3 years experience; Bachelor's degree; familiar with Docker and Linux; can write SQL."
DEFAULT_JD="Role: Backend Engineer. Requirements: Python and Java; 3-5 years; Bachelor's degree; strong SQL and Linux."

RESUME_TEXT="${1:-$DEFAULT_RESUME}"
JD_TEXT="${2:-$DEFAULT_JD}"

# Check if extraction service is available
if ! curl -s -f "${EXTRACT_SERVICE_URL}/health" > /dev/null 2>&1; then
    echo "Warning: Extraction service not available at ${EXTRACT_SERVICE_URL}" >&2
    echo "Falling back to SQL-based extraction..." >&2
    # Fallback to original SQL-based extraction
    exec "$(dirname "$0")/run_demo.sh" "$@"
fi

SQL_FILE="$(mktemp /tmp/rb_demo_spacy.XXXXXX.sql)"

# Step 1: Extract entities using Python service
echo "Extracting entities from resume..." >&2
RESUME_EXTRACT=$(curl -s -X POST "${EXTRACT_SERVICE_URL}/extract" \
    -H "Content-Type: application/json" \
    -d "{\"text\": $(python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$RESUME_TEXT"), \"doc_type\": \"RESUME\"}")

echo "Extracting entities from JD..." >&2
JD_EXTRACT=$(curl -s -X POST "${EXTRACT_SERVICE_URL}/extract" \
    -H "Content-Type: application/json" \
    -d "{\"text\": $(python3 -c "import json, sys; print(json.dumps(sys.argv[1]))" "$JD_TEXT"), \"doc_type\": \"JD\"}")

# Step 2: Generate SQL that uses extracted entities
python3 - <<'PY' "$SQL_FILE" "$RESUME_TEXT" "$JD_TEXT" "$BASELINE_SET_ID" "$RESUME_EXTRACT" "$JD_EXTRACT"
import sys, json, random, string

sql_path, resume_text, jd_text, baseline_set_id = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
resume_extract_json, jd_extract_json = sys.argv[5], sys.argv[6]

tag = "RB" + "".join(random.choice(string.ascii_letters + string.digits) for _ in range(10))
def dq(s: str) -> str:
    return f"${tag}$" + s + f"${tag}$"

# Parse extraction results
resume_extract = json.loads(resume_extract_json)
jd_extract = json.loads(jd_extract_json)

resume_entities = resume_extract.get("entities", [])
jd_entities = jd_extract.get("entities", [])

with open(sql_path, "w", encoding="utf-8") as f:
    f.write(f"""
\\set ON_ERROR_STOP on
set search_path to rb, public;

with
ins_resume as (
  insert into rb_document(doc_type, raw_text, lang, source)
  values ('RESUME', {dq(resume_text)}, 'en', 'demo_spacy')
  returning id, raw_text
),
ins_jd as (
  insert into rb_document(doc_type, raw_text, lang, source)
  values ('JD', {dq(jd_text)}, 'en', 'demo_spacy')
  returning id, raw_text
),

-- =========================
-- Box 1: Extract (spaCy + SkillNER results)
-- =========================

-- Resume entities from Python service
resume_extracted_evidence as (
  select canonical, hit, evidence_text, via
  from (values {','.join([f"('{e['canonical'].replace(\"'\", \"''\")}', {dq(e['text'])}, {dq(e.get('evidence', e['text']))}, 'spacy+skillner')" for e in resume_entities]) if resume_entities else "('', '', '', 'spacy+skillner')"} as t(canonical, hit, evidence_text, via)
  where canonical != ''
),
jd_extracted_evidence as (
  select canonical, hit, evidence_text, via
  from (values {','.join([f"('{e['canonical'].replace(\"'\", \"''\")}', {dq(e['text'])}, {dq(e.get('evidence', e['text']))}, 'spacy+skillner')" for e in jd_entities]) if jd_entities else "('', '', '', 'spacy+skillner')"} as t(canonical, hit, evidence_text, via)
  where canonical != ''
),

-- =========================
-- Box 2: Normalize (enforce baseline dictionary)
-- =========================

resume_norm as (
  select distinct e.canonical
  from resume_extracted_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),
jd_norm as (
  select distinct e.canonical
  from jd_extracted_evidence e
  join rb_baseline_term t
    on t.baseline_set_id = {baseline_set_id}
   and t.status = 'active'
   and t.canonical = e.canonical
),

-- Evidence after baseline enforcement
resume_evidence as (
  select hit, canonical, via, evidence_text
  from (
    select
      e.hit, e.canonical, e.via, e.evidence_text,
      row_number() over (
        partition by e.canonical
        order by length(e.hit) desc, e.hit asc
      ) as rn
    from resume_extracted_evidence e
    join rb_baseline_term t
      on t.baseline_set_id = {baseline_set_id}
     and t.status = 'active'
     and t.canonical = e.canonical
  ) x
  where rn = 1
),
jd_evidence as (
  select hit, canonical, via, evidence_text
  from (
    select
      e.hit, e.canonical, e.via, e.evidence_text,
      row_number() over (
        partition by e.canonical
        order by length(e.hit) desc, e.hit asc
      ) as rn
    from jd_extracted_evidence e
    join rb_baseline_term t
      on t.baseline_set_id = {baseline_set_id}
     and t.status = 'active'
     and t.canonical = e.canonical
  ) x
  where rn = 1
),

-- =========================
-- Box 3: Tagging
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
-- Box 4: Match
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

    (select coalesce(jsonb_agg(jsonb_build_object('hit',hit,'canonical',canonical,'via',via,'evidence',evidence_text) order by canonical, hit), '[]'::jsonb)
     from resume_evidence) as resume_evidence_json,

    (select coalesce(jsonb_agg(jsonb_build_object('hit',hit,'canonical',canonical,'via',via,'evidence',evidence_text) order by canonical, hit), '[]'::jsonb)
     from jd_evidence) as jd_evidence_json
),

result as (
  select jsonb_build_object(
    'baselineSetId', {baseline_set_id},
    'extractor', 'spacy+skillner',
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
