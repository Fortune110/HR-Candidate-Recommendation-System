# Complete Backend Startup Fix Guide

## 📋 A. Configuration Check Results

### 1. Spring Boot Configuration (application.yml)

```yaml
server:
  port: 18080  ✅ Port configuration correct

spring:
  datasource:
    url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db  ✅
    username: rb_user  ✅
    password: rb_password  ✅
  flyway:
    enabled: true  ✅
    locations: classpath:db/migration  ✅
```

### 2. Migration Files List (Execution Order)

```
V1__blueprint_core.sql          ✅
V2__baseline.sql                ✅
V5__candidate_pipeline_stage.sql ✅
V6__candidate_stage_history_reason_code.sql ✅
V10__rb_core.sql                ✅ (creates rb_document)
V11__rb_baseline.sql            ✅
V12__rb_review.sql              ✅
V13__success_profile_and_match.sql ✅ (creates rb_match_run, rb_match_result)
V14__ml_training_view.sql       ✅ (formerly V7, renamed)
```

**Note**: V3, V4, V7, V8, V9 are missing (Flyway will automatically skip)

### 3. Database Connection Check

- ✅ Postgres container running: `resume_blueprint_postgres`
- ✅ Database port 55434 accessible
- ✅ Database reset: `resume_blueprint_db`

---

## 🔍 B. Collect Startup Failure Evidence

### Step 1: Reset Database (Already Executed)

```powershell
$pg = "resume_blueprint_postgres"
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"
```

### Step 2: Stop Existing Java Processes

```powershell
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Step 3: Start Backend and Collect Logs

**Method 1: Run directly and observe logs**

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

**Method 2: Save logs to file**

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run 2>&1 | Tee-Object -FilePath "startup.log"
```

**Key log locations** (if startup fails, look for the following):

1. **Flyway Migration Error**:
   ```
   Failed to execute script V*.sql
   SQL State: 42P01
   Message: ERROR: relation "xxx" does not exist
   Location: db/migration/V*.sql
   Line: XX
   ```

2. **Database Connection Error**:
   ```
   Connection refused
   FATAL: password authentication failed
   ```

3. **SQL Syntax Error**:
   ```
   ERROR: syntax error at or near "xxx"
   Position: XXX
   ```

4. **BUILD FAILURE**:
   ```
   [ERROR] Failed to execute goal
   BUILD FAILURE
   ```

### Step 4: If Failed, Extract Last 80 Lines of Logs

```powershell
# If logs saved to file
Get-Content startup.log -Tail 80

# Or copy last 80 lines from console
```

---

## 🛠️ C. Common Issue Fixes (Only Modify Migrations)

### Issue 1: Table Does Not Exist Error

**Symptom**:
```
ERROR: relation "rb_xxx" does not exist
Location: db/migration/V*.sql
```

**Fix**:
- Check migration execution order
- Confirm if dependent tables are created in previous migrations
- If tables are created in later migrations, adjust migration order (rename files)

### Issue 2: SQL Syntax Error

**Symptom**:
```
ERROR: syntax error at or near "xxx"
Position: XXX
```

**Fix**:
- Open the corresponding migration file
- Check SQL syntax at specified position
- Fix syntax errors (e.g., functions in unique constraints, missing quotes, etc.)

### Issue 3: Migration Order Error

**Symptom**:
```
ERROR: relation "rb_document" does not exist
Location: db/migration/V7__xxx.sql
```

**Fix**:
- Rename migrations that depend on other tables to higher version numbers
- Example: V7 depends on V10's tables, rename V7 to V14

---

## ✅ D. Complete Fix Steps (Copy and Execute)

### Step 1: Stop Java Processes

```powershell
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Step 2: Reset Database

```powershell
$pg = "resume_blueprint_postgres"
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"
```

### Step 3: Start Backend

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

**Wait to see**:
```
Successfully applied 9 migration(s)
Started ResumeBlueprintApiApplication in X.XXX seconds
```

### Step 4: Verify Port Listening

**Execute in new PowerShell window**:

```powershell
netstat -ano | findstr :18080 | findstr LISTENING
```

**Expected output**:
```
TCP    0.0.0.0:18080    0.0.0.0:0    LISTENING    12345
```

### Step 5: Verify Page Access

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

---

## 🌐 E. Verify Upload Pipeline

### 1. Browser Access Upload Page

Open browser and visit:
```
http://127.0.0.1:18080/upload
```

**Expected**: Displays PDF upload form page

### 2. Swagger UI API Testing

Open browser and visit:
```
http://127.0.0.1:18080/swagger-ui/index.html
```

**Expected**: Displays Swagger UI interface

**Test upload endpoint**:
1. Find `PdfPipelineController` -> `POST /api/pipeline/ingest-pdf-and-match`
2. Click "Try it out"
3. Fill parameters:
   - `candidateId`: `test_candidate_001`
   - `docType`: `candidate_resume`
   - `file`: Select a PDF file
4. Click "Execute"
5. View response results

---

## 📝 Troubleshooting Checklist

If startup still fails, check in the following order:

- [ ] Postgres container running: `docker ps | Select-String postgres`
- [ ] Database port accessible: `Test-NetConnection -ComputerName 127.0.0.1 -Port 55434`
- [ ] Database reset: `docker exec resume_blueprint_postgres psql -U rb_user -d resume_blueprint_db -c "\dt"`
- [ ] Java processes stopped: `Get-Process -Name java`
- [ ] Port 18080 not occupied: `netstat -ano | findstr :18080`
- [ ] Migration files complete: Check `src/main/resources/db/migration` directory
- [ ] Migration order correct: V14 should be after V13

---

## 🚀 Quick Startup Script

Created `START_AND_COLLECT_LOG.ps1`, can run directly:

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\START_AND_COLLECT_LOG.ps1
```

The script will automatically:
1. Reset database
2. Stop Java processes
3. Start backend and save logs
4. Display last 80 lines of logs (if failed)
