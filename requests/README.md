# API Testing Guide

<<<<<<< HEAD
## Quick Start

### One-command E2E Smoke Test

Run in PowerShell:

=======
## Quick start
>>>>>>> 82b9b5f (feat: ML repro metrics, pipeline, Flyway migrations, candidate/upload APIs)
```powershell
.\requests\e2e_smoke.ps1
```

<<<<<<< HEAD
Or specify a custom base URL:
=======
## What the script does
1. Checks Docker Compose (Postgres)
2. Starts the Spring Boot app if needed
3. Calls health endpoint
4. Runs resume ingestion, extract, and match
>>>>>>> 82b9b5f (feat: ML repro metrics, pipeline, Flyway migrations, candidate/upload APIs)

## Common issues
- Port mismatch: check `application.yml` and docker-compose ports
- DB not running: start postgres in `talent-archive-core`
- Extract service down: `docker-compose up -d extract-service`

<<<<<<< HEAD
## Test Flow

The E2E script performs the following steps automatically:

1. **Check/Start Docker Compose**
   - Check whether the PostgreSQL container is running
   - If not running, attempt to start the `postgres` service in `talent-archive-core/docker-compose.yml`

2. **Start Spring Boot Application**
   - Check if the app is already running (via the health endpoint)
   - If not running, start it with `mvnw spring-boot:run`
   - Wait for the app to become ready (up to 60 seconds)

3. **Health Check**
   - GET `/api/extract/health`
   - Validate extract service availability

4. **Resume Ingestion (Golden Path Step 1)**
   - POST `/api/resumes`
   - Read `samples/resume_001.txt`
   - Verify `documentId` is returned

5. **Entity Extraction (Golden Path Step 2)**
   - POST `/api/extract`
   - Use the `documentId` from step 1
   - Note: If extract-service (Python) is not running, this step warns but does not fail

6. **Match Query (Golden Path Step 3)**
   - POST `/api/match`
   - Use the `documentId` from step 1
   - Note: If no success profile data exists, this step warns but does not fail

## Query Endpoints (for verifying writes)

```powershell
# Resume detail
Invoke-WebRequest -Uri "http://localhost:18080/api/resumes/{documentId}" -UseBasicParsing

# Resume list
Invoke-WebRequest -Uri "http://localhost:18080/api/resumes?limit=50&offset=0" -UseBasicParsing

# Match result
Invoke-WebRequest -Uri "http://localhost:18080/api/match/{matchRunId}" -UseBasicParsing
```

## Output Notes

### Success Output Example

```
========================================
  E2E Smoke Test - Resume Blueprint API
========================================
Base URL: http://localhost:18080

[10:30:15] [INFO] Checking Docker Compose...
[10:30:16] [PASS] PostgreSQL container is running
[10:30:16] [INFO] Starting Spring Boot application...
[10:30:17] [PASS] Application appears to be already running
[10:30:17] [INFO] Testing health endpoint...
[10:30:17] [INFO]   Request: GET http://localhost:18080/api/extract/health
[10:30:17] [INFO]   Status: 200
[10:30:17] [PASS] Health check passed
[10:30:17] [INFO] Testing resume ingestion...
[10:30:18] [PASS] Resume ingested successfully. Document ID: 1
[10:30:18] [INFO] Testing extract service...
[10:30:19] [PASS] Extract completed successfully
[10:30:20] [INFO] Testing match service...
[10:30:21] [PASS] Match completed successfully

========================================
  Test Results Summary
========================================
  [PASS] Health Check
  [PASS] Resume Ingestion
  [PASS] Extract Service
  [PASS] Match Service

========================================
  RESULT: PASS
========================================
```

### Failure Output Example

```
[10:30:17] [FAIL] Health check failed
  Error: Unable to connect to remote server

========================================
  RESULT: FAIL
========================================
```

Exit Code:
- `0` = all critical tests passed
- `1` = a critical test failed (health check or resume ingestion)

## Common Troubleshooting

### 1. Port Conflict

**Issue:** Database port `55434` is already in use

**Resolution:**
- Check which process is using the port: `netstat -ano | findstr :55434`
- Free the port or adjust the docker-compose port mapping to match `application.yml`

### 2. Database Name/User Mismatch

**Issue:** Application config and docker-compose are not using the same database/user

**Default Config:**
- Database: `resume_blueprint_db`
- User: `rb_user`
- Password: `rb_password`

**Resolution:** Ensure `application.yml` matches `talent-archive-core/docker-compose.yml`.

### 3. Application Startup Failure

**Checklist:**
- [ ] Java 21+ installed: `java -version`
- [ ] Maven wrapper present: `resume-blueprint/resume-blueprint-api/mvnw.cmd`
- [ ] Port 18080 not in use: `netstat -ano | findstr :18080`
- [ ] Database is running and reachable

**View Logs:**
```powershell
cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

### 4. Extract Service Unavailable

**Symptom:** Extract test shows warning "Extraction service is unavailable"

**Cause:** Python extract-service is not running

**Resolution:**
```powershell
cd talent-archive-core
docker-compose up -d extract-service
```

Wait for the service to start (about 40 seconds), then verify:
```powershell
Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing
```

### 5. Match Returns Empty Results

**Symptom:** Match test passes but returns an empty `matches` list

**Cause:** No success profile data in the database

**Resolution:** This is expected. You can import test data using:
```powershell
$body = @{
    source = "internal_employee"
    role = "Java Backend Engineer"
    level = "mid"
    company = "Test Corp"
    text = "Backend engineer with Java/Spring experience..."
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:18080/api/success-profiles/import" `
    -Method POST -Body $body -ContentType "application/json"
```

## HTTP Client File

The `api.http` file works with the VS Code REST Client extension or the IntelliJ HTTP Client.

### VS Code
1. Install the "REST Client" extension
2. Open `requests/api.http`
3. Set environment variable `baseUrl = http://localhost:18080`
4. Click "Send Request" above the request

### IntelliJ IDEA
1. Open `requests/api.http`
2. Click the run icon next to the request

## Log Viewing

### Spring Boot Application Logs
If the app runs in the foreground, logs are printed to the console.

If it runs in the background, logs are usually in:
- Windows: the PowerShell window that started the app
- Or redirected to a file: `\mvnw.cmd spring-boot:run > app.log 2>&1`

### Docker Container Logs
```powershell
# PostgreSQL logs
docker logs resume_blueprint_postgres

# Extract Service logs
docker logs resume_blueprint_extract
```

## Performance Testing

You can call the API repeatedly for performance testing:

```powershell
$resumeText = Get-Content "samples\resume_001.txt" -Raw
$body = @{ candidateId = "perf_test_001"; text = $resumeText } | ConvertTo-Json

Measure-Command {
    1..10 | ForEach-Object {
        Invoke-WebRequest -Uri "http://localhost:18080/api/resumes" `
            -Method POST -Body $body -ContentType "application/json" | Out-Null
    }
}
```

## Next Steps

- See `docs/TESTING.md` for detailed test acceptance criteria
- Run JUnit integration tests: `.\resume-blueprint\resume-blueprint-api\mvnw.cmd test`
- View API docs (if Swagger is enabled): `/swagger-ui/index.html` or `/v3/api-docs`
=======
## Manual calls
Use `requests/api.http` with VS Code REST Client or IntelliJ HTTP client.
>>>>>>> 82b9b5f (feat: ML repro metrics, pipeline, Flyway migrations, candidate/upload APIs)
