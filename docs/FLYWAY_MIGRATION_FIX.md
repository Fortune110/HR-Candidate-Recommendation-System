# Flyway Migration Version Fix

## Problem
Flyway error: `Found more than one migration with version 1`

Cause: multiple migrations resolve to version 1:
- `V1__blueprint_core.sql` (version 1)
- `V1_1__rb_core.sql` (Flyway parses as version 1 because it stops at the first underscore)

## Solution
Move all rb-module migrations into a higher version range (start at V10) to avoid conflicts.

### Rename list
| Old filename | New filename | Note |
| --- | --- | --- |
| `V1_1__rb_core.sql` | `V10__rb_core.sql` | rb core |
| `V2_1__rb_baseline.sql` | `V11__rb_baseline.sql` | rb baseline |
| `V3__rb_review.sql` | `V12__rb_review.sql` | rb review |
| `V4__success_profile_and_match.sql` | `V13__success_profile_and_match.sql` | success profile + match |

### Final version order
1. V1__blueprint_core.sql  
2. V2__baseline.sql  
3. V5__candidate_pipeline_stage.sql  
4. V6__candidate_stage_history_reason_code.sql  
5. V7__ml_training_view.sql  
6. V10__rb_core.sql  
7. V11__rb_baseline.sql  
8. V12__rb_review.sql  
9. V13__success_profile_and_match.sql

## Verification
```powershell
cd resume-blueprint/resume-blueprint-api
.\mvnw.cmd clean test
```
Expected: no `Found more than one migration with version X` errors.

## Checksum mismatch (if it happens)
If you see:
```
Migration checksum mismatch for migration version 1
Migration checksum mismatch for migration version 2
```
It means the database has old checksums from before the rename.

### Option 1: reset the dev database (recommended)
See `docs/DATABASE_RESET_GUIDE.md` for full steps. Quick version:
```powershell
cd talent-archive-core
docker compose down -v
docker compose up -d postgres
Start-Sleep -Seconds 5

cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

### Option 2: manual cleanup (production only, use caution)
```sql
psql "postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db"
SELECT * FROM flyway_schema_history ORDER BY installed_rank;
DELETE FROM flyway_schema_history WHERE version IN ('1.1', '2.1');
```

### Option 3: Flyway repair (if supported)
```powershell
.\mvnw.cmd flyway:repair
```

## Notes
- Versions must be unique.
- Execution order follows version numbers, not file name order.
- Renaming applied migrations requires database cleanup.

## Related paths
- `resume-blueprint/resume-blueprint-api/src/main/resources/db/migration/`
- `talent-archive-core/docker-compose.yml`
