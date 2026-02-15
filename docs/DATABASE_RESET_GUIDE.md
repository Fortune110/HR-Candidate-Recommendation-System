# Database Reset Guide

## Configuration
**Main config:** `resume-blueprint/resume-blueprint-api/src/main/resources/application.yml`
```yaml
spring:
  datasource:
    url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db
    username: rb_user
    password: rb_password
```

**Docker Compose:** `talent-archive-core/docker-compose.yml`
- container: `resume_blueprint_postgres`
- image: `postgres:16`
- ports: `55434:5432`
- volume: `rb_pgdata`

## Full reset (Docker Compose)
```powershell
cd C:\HR-Candidate-Recommendation-System\talent-archive-core
docker compose down -v
docker compose up -d postgres
Start-Sleep -Seconds 5

cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

## Optional one-click script
Save as `reset-db.ps1`:
```powershell
Set-Location $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Reset DB and run tests" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`n[1/4] Stopping and removing containers + volumes..." -ForegroundColor Yellow
Set-Location talent-archive-core
docker compose down -v
if ($LASTEXITCODE -ne 0) { Write-Host "docker compose down failed" -ForegroundColor Red; exit 1 }

Write-Host "`n[2/4] Starting postgres..." -ForegroundColor Yellow
docker compose up -d postgres
if ($LASTEXITCODE -ne 0) { Write-Host "docker compose up failed" -ForegroundColor Red; exit 1 }

Write-Host "`n[3/4] Waiting for DB (10s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$containerStatus = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.Name -eq "resume_blueprint_postgres" }
if ($containerStatus.Status -notlike "*Up*") { Write-Host "Postgres not ready" -ForegroundColor Red; exit 1 }
Write-Host "Postgres status: $($containerStatus.Status)" -ForegroundColor Green

Write-Host "`n[4/4] Running tests..." -ForegroundColor Yellow
Set-Location ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

## Non-Docker alternatives
### Option 1: drop and recreate the database
```powershell
$env:PGPASSWORD = "your_postgres_password"
psql -h localhost -p 55434 -U postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
psql -h localhost -p 55434 -U postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"

cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

### Option 2: remove Flyway history only (keeps data)
```powershell
$env:PGPASSWORD = "rb_password"
psql -h localhost -p 55434 -U rb_user -d resume_blueprint_db -c "DROP TABLE IF EXISTS flyway_schema_history CASCADE;"

cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

### Option 3: drop all tables (keeps database)
```powershell
$env:PGPASSWORD = "rb_password"
$sql = @"
DO \$\$ 
DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public')
  LOOP
    EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END \$\$;
"@

psql -h localhost -p 55434 -U rb_user -d resume_blueprint_db -c $sql

cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd clean test
```

## Quick checks
```powershell
cd talent-archive-core
docker compose ps
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT version();"
docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT version, description, installed_on FROM flyway_schema_history ORDER BY installed_rank;"
```

## Troubleshooting
- checksum mismatch: reset the DB or clean Flyway history.
- Docker vs local DB: `docker ps | Select-String "55434"`.
- Port conflict: `netstat -ano | findstr :55434`.
