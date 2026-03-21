# Quick Fix Guide

## Fixed Issues

### Issue 1 — Database Config Mismatch (Fixed)

**What was fixed:**
- Updated `application.yml` to match docker-compose settings
- Port: `55433` → `55434`
- Database: `talent_archive` → `resume_blueprint_db`
- User: `archive_user` → `rb_user`
- Password: `archive_pass` → `rb_password`

**Verify the fix:**
```bash
# 1. Check containers are running
cd talent-archive-core
docker compose ps
# Should show: resume_blueprint_postgres running, port 0.0.0.0:55434->5432/tcp

# 2. Test database connection
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;"
# Should return 1 row

# 3. Start backend and check logs
cd ../resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
# Should see Flyway migrations succeed with no connection errors
```

---

## Verification Steps

### 1. Check Docker containers

```bash
cd talent-archive-core
docker compose ps
```

Expected:
```
NAME                        IMAGE       STATUS       PORTS
resume_blueprint_postgres   postgres:16 Up X minutes 0.0.0.0:55434->5432/tcp
```

### 2. Verify database access

```bash
PGPASSWORD=rb_password psql -h 127.0.0.1 -p 55434 -U rb_user -d resume_blueprint_db -c "\dt rb_*"
```

Should list tables: `rb_document`, `rb_run`, `rb_canonical_tag`, etc.

### 3. Start the backend

```bash
cd resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
```

Look for:
- `Started ResumeBlueprintApiApplication` — app started
- `Successfully validated X migrations` — Flyway OK

---

## Troubleshooting

### Problem A — Database connection error on startup

Check:
```bash
# Containers running?
docker compose ps

# Correct config in application.yml?
grep -A3 "datasource" src/main/resources/application.yml
# Should show: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db
```

### Problem B — Flyway migration failed

```bash
# Reset Flyway history (last resort)
PGPASSWORD=rb_password psql -h 127.0.0.1 -p 55434 -U rb_user -d resume_blueprint_db \
  -c "DELETE FROM flyway_schema_history WHERE success = false;"
```

### Problem C — Extract service unavailable

```bash
# Check if Python service is running
curl -s http://127.0.0.1:5000/health

# Start it if needed
cd talent-archive-core/extract-service
python extract_service.py &
```
