#!/usr/bin/env bash
set -euo pipefail

CANDIDATE_ID="${1:-}"
JSON_FILE="${2:-}"
DB_URL="${DB_URL:-postgresql://archive_user:archive_pass@localhost:55433/talent_archive}"

if [[ -z "$CANDIDATE_ID" || -z "$JSON_FILE" ]]; then
  echo "Usage: $0 <candidate_id> <archive_json_file>"
  echo "Optional env vars:"
  echo "  AI_SOURCE=resume_parse_v1 AI_MODEL=gpt-4o-mini $0 101 file.json"
  exit 1
fi

if [[ ! -f "$JSON_FILE" ]]; then
  echo "File not found: $JSON_FILE"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for JSON validation. Install with: brew install jq"
  exit 1
fi

# Validate JSON syntax
jq -e . "$JSON_FILE" >/dev/null || {
  echo "Invalid JSON: $JSON_FILE"
  exit 1
}

# Minimal schema validation:
# - behavior_tags/skill_tags/risk_tags must be arrays
# - optional _meta must be an object if present
jq -e '
  (.behavior_tags | type == "array") and
  (.skill_tags | type == "array") and
  (.risk_tags | type == "array") and
  ((has("_meta") | not) or (._meta | type == "object"))
' "$JSON_FILE" >/dev/null || {
  echo "Invalid schema: require behavior_tags/skill_tags/risk_tags as arrays; optional _meta must be an object"
  exit 1
}

ARCHIVE_JSON="$(cat "$JSON_FILE")"

psql "$DB_URL" \
  -v ON_ERROR_STOP=1 \
  -v candidate_id="$CANDIDATE_ID" \
  -v archive_json="$ARCHIVE_JSON" \
  -v ai_source="${AI_SOURCE:-}" \
  -v ai_model="${AI_MODEL:-}" \
  -f ingest/ingest_archive.sql
