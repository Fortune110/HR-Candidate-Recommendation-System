#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-behavior}"
DB_URL="${DB_URL:-postgresql://archive_user:archive_pass@localhost:55433/talent_archive}"

case "$TYPE" in
  behavior) FILE="sql/rank_behavior.sql" ;;
  skill)    FILE="sql/rank_skill.sql" ;;
  risk)     FILE="sql/rank_risk.sql" ;;
  *)
    echo "Usage: $0 {behavior|skill|risk}"
    exit 1
    ;;
esac

psql "$DB_URL" -f "$FILE"
