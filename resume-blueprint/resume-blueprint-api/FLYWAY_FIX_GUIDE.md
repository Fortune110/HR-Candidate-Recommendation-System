# Flyway Validation Fix Guide

## What happened
Flyway validation failed because database migration history does not match the local files.

## Recommended fix (dev only)
Reset the database so migrations can run cleanly.

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\FIX_FLYWAY.ps1
```

## Manual reset (if needed)
```powershell
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"

cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

## Verify
```powershell
netstat -ano | Select-String ":18080" | Select-String "LISTENING"
curl -I http://localhost:18080/upload
curl -I http://localhost:18080/swagger-ui/index.html
```
