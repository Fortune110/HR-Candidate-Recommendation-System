# PDF Upload Page Usage Guide

## ✅ Completed Configuration

1. ✅ Added Swagger UI dependency (springdoc-openapi-starter-webmvc-ui:2.3.0)
2. ✅ Created upload page Controller (UploadPageController)
3. ✅ Created HTML upload page (upload.html)
4. ✅ Updated PdfPipelineController to support file upload

## 🚀 Startup Steps

### 1. Start Backend Application

```powershell
# Navigate to project directory
cd resume-blueprint\resume-blueprint-api

# Start application
.\mvnw.cmd spring-boot:run
```

**Wait to see the following log indicating successful startup:**
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

### 2. Access Upload Page

After successful startup, access in browser:

- **Upload Page (Recommended for non-technical users)**:
  ```
  http://localhost:18080/upload
  ```

- **Swagger UI (Recommended for developers)**:
  ```
  http://localhost:18080/swagger-ui/index.html
  ```

## 📋 Feature Description

### Upload Page Features

1. **Candidate ID**: Required, auto-generates UUID if left empty
2. **Document Type**: Dropdown selection, supports:
   - candidate_resume (default)
   - resume
   - jd
   - job_description
   - job
3. **Job ID**: Optional, if provided will perform match analysis
4. **PDF File**: Required, PDF format only, maximum 10MB

### Result Display

- ✅ **Success**: Displays traceId, documentId, extractRunId, textLength, and matchResult if jobId provided
- ❌ **Failure**: Displays error messages (non-PDF/docType not supported/scanned PDF textLength too short/extract-service not started, etc.)

## 🔍 Troubleshooting

### Issue 1: Page 404 or Cannot Access

**Reason**: Backend not started or startup failed

**Solution**:
1. Check if backend is running: `Get-Process -Name java`
2. Check if port is occupied: `netstat -ano | findstr :18080`
3. Check startup logs for errors

### Issue 2: Swagger UI 404

**Reason**: Dependency may not be loaded correctly

**Solution**:
1. Recompile: `.\mvnw.cmd clean compile`
2. Restart application

### Issue 3: Upload Failed - "Extract Service Not Started"

**Reason**: extract-service not running

**Solution**:
```powershell
cd talent-archive-core
docker-compose up -d extract-service
```

### Issue 4: Upload Failed - "Scanned PDF textLength Too Short"

**Reason**: Uploaded PDF is scanned (image-based), not text-based PDF

**Solution**: Use text-based PDF (can export from Word to PDF)

## 📝 Testing Steps

1. ✅ Start backend: `.\mvnw.cmd spring-boot:run`
2. ✅ Wait for startup completion (see "Started ResumeBlueprintApiApplication")
3. ✅ Open browser and access `http://localhost:18080/upload`
4. ✅ Fill candidateId (or use auto-generated)
5. ✅ Select PDF file
6. ✅ Click "Upload and Process"
7. ✅ View results (success will show traceId and related information)

## 🎯 Expected Results

**Successful upload (no jobId)**:
```json
{
  "ok": true,
  "message": "PDF ingested and extracted; jobId not provided, skipped match.",
  "traceId": "...",
  "documentId": 1,
  "extractRunId": 1,
  "textLength": 1234,
  "matchResult": null
}
```

**Successful upload (with jobId)**:
```json
{
  "ok": true,
  "message": "PDF processed successfully",
  "traceId": "...",
  "documentId": 1,
  "extractRunId": 1,
  "textLength": 1234,
  "matchResult": {
    "matchRunId": 1,
    "matches": [...]
  }
}
```
