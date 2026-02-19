# Backend Startup and Accessibility Verification Guide

## 📋 A. Verify Facts (Code Evidence)

### 1. Server Port Configuration

**File**: `src/main/resources/application.yml`
```yaml
server:
  port: 18080  ✅
```

### 2. Upload Page File Path

**File**: `src/main/resources/static/upload.html` ✅ Exists

### 3. Upload Page Controller Mapping

**File**: `src/main/java/com/fortune/resumeblueprint/api/UploadPageController.java`

```java
@RestController
public class UploadPageController {
    @GetMapping(value = "/upload", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> uploadPage() {
        // Reads static/upload.html and returns it
    }
}
```

**Conclusion**: 
- ✅ **Access URL is `/upload`** (not `/upload.html`)
- ✅ **Reason**: Controller uses `@GetMapping("/upload")` mapping, directly returning HTML content
- ✅ If accessing `/upload.html` directly, Spring Boot's static resource handler will try to serve from `static/upload.html`, but Controller mapping has higher priority

### 4. Swagger Configuration

**File**: `pom.xml`
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

**Swagger UI URL**: `http://127.0.0.1:18080/swagger-ui/index.html` ✅

---

## 🚀 B. Get the Backend Running

### Quick Start (Using Script)

```powershell
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\START_AND_VERIFY.ps1
```

### Manual Startup Steps

```powershell
# 1. Stop existing Java processes
Get-Process -Name java -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Reset database
$pg = "resume_blueprint_postgres"
docker exec $pg psql -U rb_user -d postgres -c "DROP DATABASE IF EXISTS resume_blueprint_db;"
docker exec $pg psql -U rb_user -d postgres -c "CREATE DATABASE resume_blueprint_db OWNER rb_user;"

# 3. Start backend
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

**Wait to see**:
```
Successfully applied 9 migration(s)
Started ResumeBlueprintApiApplication in X.XXX seconds
```

**If startup fails**:
- Look for `Failed to execute script V*.sql` in logs
- Locate the specific migration file and line number
- Only fix migration SQL (don't modify business Java code)

---

## ✅ C. Reproducible Verification Steps

### Step 1: Verify Port Listening

```powershell
netstat -ano | findstr :18080 | findstr LISTENING
```

**Expected output**:
```
TCP    0.0.0.0:18080    0.0.0.0:0    LISTENING    12345
```

### Step 2: Verify HTTP Connectivity

```powershell
# Test root path
curl -I http://127.0.0.1:18080/

# Test upload page
curl -I http://127.0.0.1:18080/upload

# Test Swagger UI
curl -I http://127.0.0.1:18080/swagger-ui/index.html
```

**Expected output** (200/302/401 all count as connected):
```
HTTP/1.1 200 OK
or
HTTP/1.1 302 Found
```

### Step 3: Confirm Correct Upload Page URL

**Code evidence**:
- `UploadPageController.java` line 19: `@GetMapping(value = "/upload")`
- File path: `src/main/resources/static/upload.html`

**Conclusion**:
- ✅ **Correct URL**: `http://127.0.0.1:18080/upload`
- ❌ **Incorrect URL**: `http://127.0.0.1:18080/upload.html` (although file exists, Controller mapping has higher priority)

**Reason**:
- Controller's `@GetMapping("/upload")` intercepts `/upload` requests
- Even if `static/upload.html` exists, it won't be accessed via static resource path
- Controller directly reads file content and returns it, so accessing `/upload` is sufficient

---

## 🔍 D. If Still Getting ERR_CONNECTION_REFUSED

### Cause 1: Java Process Exited

**Verification command**:
```powershell
Get-Process -Name java -ErrorAction SilentlyContinue
```

**If output is empty**: Java process has exited, need to restart

**Check startup logs**:
```powershell
# View startup logs (if saved)
Get-Content startup.log -Tail 80

# Or restart and observe errors
cd C:\HR-Candidate-Recommendation-System\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

### Cause 2: Port is Not 18080

**Verification command**:
```powershell
# Check all ports listened by Java processes
netstat -ano | findstr LISTENING | findstr java

# Or find from startup logs
# Look for "Tomcat initialized with port"
```

**If port is not 18080**:
- Check `server.port` configuration in `application.yml`
- Check if environment variable overrides: `SERVER_PORT`

### Cause 3: Binding Address Issue

**Verification command**:
```powershell
netstat -ano | findstr :18080
```

**Analyze output**:
- `0.0.0.0:18080` - Listening on all interfaces ✅
- `127.0.0.1:18080` - Only listening on localhost ✅
- `[::1]:18080` - Only listening on IPv6 localhost ⚠️
- `[::]:18080` - Listening on all IPv6 interfaces ✅

**If only listening on IPv6**:
- Try accessing `http://[::1]:18080/upload`
- Or modify config to listen on IPv4: `server.address: 0.0.0.0`

---

## 📝 Complete Verification Checklist

- [ ] Java process running: `Get-Process -Name java`
- [ ] Port 18080 listening: `netstat -ano | findstr :18080 | findstr LISTENING`
- [ ] Root path accessible: `curl -I http://127.0.0.1:18080/` returns 200/302/401
- [ ] Upload page accessible: `curl -I http://127.0.0.1:18080/upload` returns 200
- [ ] Swagger UI accessible: `curl -I http://127.0.0.1:18080/swagger-ui/index.html` returns 200
- [ ] Browser access works: `http://127.0.0.1:18080/upload` displays upload form

---

## 🎯 Final Verification

### Browser Access

1. **Upload Page**:
   ```
   http://127.0.0.1:18080/upload
   ```
   Expected: Displays PDF upload form page

2. **Swagger UI**:
   ```
   http://127.0.0.1:18080/swagger-ui/index.html
   ```
   Expected: Displays Swagger UI interface, can test APIs

### API Testing (Swagger UI)

1. Find `PdfPipelineController` -> `POST /api/pipeline/ingest-pdf-and-match`
2. Click "Try it out"
3. Fill parameters and upload PDF file
4. Click "Execute"
5. View response results

---

## 🚨 Troubleshooting Priority

1. **Highest Priority**: Is Java process running (`Get-Process -Name java`)
2. **Second Priority**: Is port listening (`netstat -ano | findstr :18080`)
3. **Third Priority**: Error messages in startup logs (Flyway migration failures, etc.)
