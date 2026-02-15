# Backend Startup Debugging Guide

## 📋 Current Status Check

### A. Configuration File Check

**application.yml**:
- ✅ `server.port: 18080` - Port configuration correct
- ✅ `spring.datasource.url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db`
- ✅ `spring.flyway.enabled: true`
- ✅ `spring.flyway.locations: classpath:db/migration`

### B. Migration Files List

Current migrations (execution order):
1. V1__blueprint_core.sql
2. V2__baseline.sql
3. V5__candidate_pipeline_stage.sql
4. V6__candidate_stage_history_reason_code.sql
5. V10__rb_core.sql
6. V11__rb_baseline.sql
7. V12__rb_review.sql
8. V13__success_profile_and_match.sql
9. V14__ml_training_view.sql (formerly V7, renamed)

**Note**: V3, V4, V7, V8, V9 are missing (this is normal, Flyway will skip missing version numbers)

---

## 🔍 Collect Startup Failure Evidence

### Step 1: Ensure Database is Reset

```powershell
# Find Postgres container
$pg = (docker ps --format "{{.Names}} {{.Image}}" | Select-String "postgres" | ForEach-Object { $_.ToString().Split(" ")[0] } | Select-Object -First 1)
Write-Host "Postgres container: $pg"

# Reset database
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"
```

### Step 2: Start Backend and Collect Logs

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# Start and save logs to file
.\mvnw.cmd spring-boot:run 2>&1 | Tee-Object -FilePath "startup.log"

# Or run directly, then copy last 80 lines
.\mvnw.cmd spring-boot:run
```

**Key log locations**:
- Look for `ERROR` or `FAILURE`
- Look for `FlywayMigrateException` or `FlywayValidateException`
- Look for `Failed to execute script`
- Look for `SQL State` and `Error Code`
- Look for `BUILD FAILURE`

### Step 3: If Startup Fails, Check Last 80 Lines

```powershell
# If logs saved to file
Get-Content startup.log -Tail 80

# Or copy last 80 lines from console output
```

---

## 🛠️ Common Issue Diagnosis

### Issue 1: Flyway Migration Failure

**Symptom**:
```
Failed to execute script V*.sql
SQL State: 42P01
Message: ERROR: relation "xxx" does not exist
```

**Diagnosis**:
- Check the failed migration file
- Confirm if dependent tables are created
- Check migration execution order

### Issue 2: Database Connection Failure

**Symptom**:
```
Connection refused
FATAL: password authentication failed
```

**Diagnosis**:
- Check if Postgres container is running: `docker ps | Select-String postgres`
- Check if port 55434 is accessible: `Test-NetConnection -ComputerName 127.0.0.1 -Port 55434`
- Check database configuration in application.yml

### Issue 3: Port Already in Use

**Symptom**:
```
Web server failed to start. Port 18080 was already in use.
```

**Diagnosis**:
```powershell
netstat -ano | findstr :18080
# Find PID then terminate process
Stop-Process -Id <PID> -Force
```

---

## ✅ Post-Fix Verification Steps

### 1. Confirm Backend Startup Success

**Must see in logs**:
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

### 2. Confirm Port Listening

```powershell
netstat -ano | findstr :18080 | findstr LISTENING
```

**Expected output**:
```
TCP    0.0.0.0:18080    0.0.0.0:0    LISTENING    12345
```

### 3. Test Page Access

```powershell
# Test upload page
curl -I http://127.0.0.1:18080/upload

# Test Swagger UI
curl -I http://127.0.0.1:18080/swagger-ui/index.html
```

**Expected output**:
```
HTTP/1.1 200 OK
or
HTTP/1.1 302 Found
```

### 4. Browser Verification

- Open `http://127.0.0.1:18080/upload` - Should display upload page
- Open `http://127.0.0.1:18080/swagger-ui/index.html` - Should display Swagger UI

---

## 📝 Next Steps

Please run the startup command and collect error logs, then fix according to specific error messages.
