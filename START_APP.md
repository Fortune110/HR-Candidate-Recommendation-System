# Application Startup Guide

## ✅ Java 21 is Correctly Installed

Verification Results:
- Java Version: 21.0.8 ✅
- javac Compiler: Available ✅
- Maven Recognizes Java 21 ✅

---

## 🚀 Starting the Application (Run in Foreground to View Logs)

**Important:** Please manually run the following commands in PowerShell, and do not close the window so you can see startup logs and any errors:

```powershell
# 1. Navigate to backend directory
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api

# 2. Start application (keep window open)
.\mvnw.cmd spring-boot:run
```

**First startup may take 1-2 minutes** (downloading dependencies, compiling code, etc.).

---

## 📋 What You Should See During Startup:

### ✅ Signs of Successful Startup:

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v4.0.1)

...(Flyway migration logs)...

Started ResumeBlueprintApiApplication in X.XXX seconds
```

### ❌ If You See Errors:

**Database Connection Error:**
```
org.postgresql.util.PSQLException: Connection refused
```
→ Check if database container is running: `docker compose ps` (in talent-archive-core directory)

**Port Already in Use:**
```
Web server failed to start. Port 18080 was already in use.
```
→ Check port usage: `netstat -ano | findstr :18080`

**Flyway Migration Failed:**
```
FlywayException: ...
```
→ Check if database configuration is correct (should be 55434 / resume_blueprint_db / rb_user)

---

## 🔍 Verify After Successful Startup

**Open a new PowerShell window** and execute:

```powershell
# Health check
Invoke-WebRequest -Uri "http://localhost:18080/api/extract/health" -UseBasicParsing
```

**Expected Response:**
```
StatusCode        : 200
Content           : {"runId":0,"message":"Extraction service is available"}
```

---

## 🧪 Then Run E2E Tests

```powershell
cd C:\HR-Candidate-Recommendation-System
.\requests\e2e_smoke.ps1
```

---

## 💡 Tips

- **First startup is slow**: Maven needs to download dependencies and compile code, may take 1-2 minutes
- **Keep window open**: Startup logs will be displayed in this window
- **If there are errors**: Copy the error message to me, and I can help troubleshoot
