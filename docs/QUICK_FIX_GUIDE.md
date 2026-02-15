# Quick Fix Guide

## Fixed items summary
- App DB config aligned with Docker Compose
- Postgres port uses `55434`
- DB name: `resume_blueprint_db`
- User/password: `rb_user` / `rb_password`

## Quick verification
```powershell
cd talent-archive-core
docker compose ps
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;"

cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

## Health check
```powershell
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

## If something still fails
- Check port conflicts: `netstat -ano | findstr :55434`
- Confirm config: `resume-blueprint/resume-blueprint-api/src/main/resources/application.yml`
- Look for Flyway migration errors in the app logs
