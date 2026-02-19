# Quick Start Guide

## Current Status ✅

- ✅ PostgreSQL Database: Running (Port 55434)
- ✅ Extract Service (Python): Running (Port 5000)
- ⚠️ Backend Application: Not Started (Manual startup required)

---

## Startup Steps

### Step 1: Start Backend Application

**Open a new PowerShell window** and execute:

```powershell
# Navigate to project root
cd C:\HR-Candidate-Recommendation-System

# Navigate to backend directory
cd resume-blueprint\resume-blueprint-api

# Start application (this will occupy the current window, showing logs)
.\mvnw.cmd spring-boot:run
```

**Wait to see:**
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

**If you see database connection errors:**
- Check if database configuration in application.yml is correct (should be 55434 / resume_blueprint_db / rb_user)
- Confirm database container is running: `docker compose ps` (in talent-archive-core directory)

---

### Step 2: Verify Application Startup (in new window or original window)

**Open another PowerShell window** and execute:

```powershell
# Health check
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

**Expected Output:**
```
StatusCode        : 200
Content           : {"runId":0,"message":"Extraction service is available"}
```

---

### Step 3: Run E2E Tests

```powershell
# Return to project root
cd C:\HR-Candidate-Recommendation-System

# Run E2E tests
.\requests\e2e_smoke.ps1
```

**Expected Output:**
```
========================================
  E2E Smoke Test - Resume Blueprint API
========================================
[PASS] Health Check
[PASS] Resume Ingestion
[PASS] Extract Service
[PASS] Match Service

========================================
  RESULT: PASS
========================================
```

---

## One-Click Command (If You Want It to Run in Background)

If you want to start the backend application in the background (without occupying the window), use:

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
Start-Process powershell -ArgumentList "-NoExit", "-Command", ".\mvnw.cmd spring-boot:run"
```

This will open a new window to run the application, and you can continue executing other commands in the current window.

---

## Troubleshooting

### Issue: Backend startup failed, database connection error

**Check:**
1. Is database container running:
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\talent-archive-core
   docker compose ps
   ```

2. Is database configuration correct:
   ```powershell
   type C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api\src\main\resources\application.yml
   ```
   Should see:
   ```yaml
   url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db
   username: rb_user
   password: rb_password
   ```

3. Manually test database connection:
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\talent-archive-core
   docker compose exec postgres psql -U rb_user -d resume_blueprint_db -c "SELECT 1;"
   ```

### Issue: Port 18080 is already in use

**Check:**
```powershell
netstat -ano | findstr :18080
```

**Solution:**
- Find the process PID using the port (last column)
- Terminate process: `taskkill /PID <PID> /F`
- Or modify the port in application.yml

---

## Summary

**Simplest startup method (3 windows):**

1. **Window 1 - Backend Application (keep running):**
   ```powershell
   cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
   .\mvnw.cmd spring-boot:run
   ```

2. **Window 2 - Wait 20 seconds then verify:**
   ```powershell
   Start-Sleep -Seconds 20
   Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
   ```

3. **Window 3 - Run tests:**
   ```powershell
   cd C:\HR-Candidate-Recommendation-System
   .\requests\e2e_smoke.ps1
   ```
