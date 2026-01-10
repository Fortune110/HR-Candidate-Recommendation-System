# Extract Service Test Commands

## Routes Summary

| Path | Method | Description | Request Body |
|------|--------|-------------|--------------|
| `/health` | GET | Health check | None |
| `/extract` | POST | Extract entities from text | `{"text": "...", "doc_type": "RESUME"\|"JD"}` (optional) |
| `/extract/batch` | POST | Batch extraction | `{"texts": [...]}` |

## Request/Response Schema

### POST /extract
**Request:**
```json
{
  "text": "resume or JD text...",
  "doc_type": "RESUME"  // Optional: "RESUME" or "JD", defaults to "RESUME"
}
```

**Response:**
```json
{
  "entities": [
    {
      "type": "skill" | "ner",
      "label": "SKILL" | "PERSON" | "ORG" | "DATE" | ...,
      "text": "original text",
      "normalized": "normalized form",
      "canonical": "skill/python" | "ner/ORG/Google" | ...,
      "start": 0,
      "end": 6,
      "evidence": "context around the entity"
    }
  ],
  "summary": "brief summary",
  "extractor": "spacy+skillner",
  "extractor_version": "1.0",
  "doc_type": "RESUME" | "JD"
}
```

## PowerShell Test Commands

### 1. Health Check
```powershell
# Test GET /health
Invoke-WebRequest -Uri "http://localhost:5000/health" -Method GET -UseBasicParsing | Select-Object -ExpandProperty Content
```

### 2. Extract from Resume
```powershell
# Prepare resume text
$resumeText = @"
John Doe
Email: john.doe@email.com | Location: Sydney, AU | LinkedIn: linkedin.com/in/johndoe

Summary:
Backend Engineer with 3+ years experience building REST APIs and data pipelines.

Skills:
Python3, SQL (PostgreSQL), Docker, Linux, Git, AWS

Experience:
- Backend Engineer, ABC Fintech (2022-2025)
  Built Python FastAPI services, optimized SQL queries, deployed with Docker on Linux.
  Developed ETL jobs and improved latency by 30%.

Education:
Bachelor's degree in Computer Science (2018-2022)
"@

# Create request body
$resumeBody = @{
    text = $resumeText
    doc_type = "RESUME"
} | ConvertTo-Json

# Send request
$resumeResponse = Invoke-WebRequest -Uri "http://localhost:5000/extract" -Method POST -Body $resumeBody -ContentType "application/json" -UseBasicParsing

# Parse and display results
$resumeJson = $resumeResponse.Content | ConvertFrom-Json
Write-Host "Summary: $($resumeJson.summary)"
Write-Host "Extracted $($resumeJson.entities.Count) entities"
$resumeJson | ConvertTo-Json -Depth 10
```

### 3. Extract from JD
```powershell
# Prepare JD text
$jdText = @"
Role: Backend Engineer (Python)
Requirements:
- 3-5 years of backend development experience
- Strong Python and SQL skills
- Experience with Docker and Linux
- Git and CI/CD experience
- Bachelor's degree required
Nice to have:
- AWS, FastAPI, data pipeline experience
"@

# Create request body
$jdBody = @{
    text = $jdText
    doc_type = "JD"
} | ConvertTo-Json

# Send request
$jdResponse = Invoke-WebRequest -Uri "http://localhost:5000/extract" -Method POST -Body $jdBody -ContentType "application/json" -UseBasicParsing

# Parse and display results
$jdJson = $jdResponse.Content | ConvertFrom-Json
Write-Host "Summary: $($jdJson.summary)"
Write-Host "Extracted $($jdJson.entities.Count) entities"
$jdJson | ConvertTo-Json -Depth 10
```

## One-Liner Commands (Quick Test)

### Health Check
```powershell
(Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing).Content
```

### Resume Extraction
```powershell
$r = @{text="John Doe`nEmail: john.doe@email.com`nSummary: Backend Engineer with 3+ years. Skills: Python, Docker, AWS"; doc_type="RESUME"} | ConvertTo-Json; (Invoke-WebRequest -Uri "http://localhost:5000/extract" -Method POST -Body $r -ContentType "application/json" -UseBasicParsing).Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

### JD Extraction
```powershell
$j = @{text="Role: Backend Engineer`nRequirements: Python, SQL, Docker, Linux"; doc_type="JD"} | ConvertTo-Json; (Invoke-WebRequest -Uri "http://localhost:5000/extract" -Method POST -Body $j -ContentType "application/json" -UseBasicParsing).Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
```

## Test Results

✅ **Service Status**: Healthy
✅ **Models Loaded**: Yes (spaCy en_core_web_sm)
✅ **Resume Extraction**: 19 entities extracted (7 skills + 12 NER)
✅ **JD Extraction**: 10 entities extracted (7 skills + 3 NER)

## Notes

- Service runs on `http://localhost:5000`
- No heavy dependencies (only spaCy small model, no transformer/trf)
- Fallback skill extraction uses keyword matching (no SkillNER dependency)
- All endpoints use standard JSON request/response format
