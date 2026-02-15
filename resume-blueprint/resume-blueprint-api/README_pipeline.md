# PDF Pipeline API

## Endpoint
`POST /api/pipeline/ingest-pdf-and-match`

## Purpose
Upload a PDF resume and run the full pipeline: extract text → persist → entity extraction → match.

## Request (multipart/form-data)
| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| `candidateId` | String | yes | - | Candidate identifier |
| `jobId` | String | no | - | Optional job id for matching |
| `docType` | String | no | `candidate_resume` | See whitelist below |
| `file` | MultipartFile | yes | - | PDF file (max 10MB) |

### docType whitelist (case-insensitive)
| Input | Mapped value |
| --- | --- |
| `candidate_resume` | `RESUME` |
| `resume` | `RESUME` |
| `jd` | `JD` |
| `job_description` | `JD` |
| `job` | `JD` |
| not provided | `RESUME` |
| anything else | error |

## Response
```json
{
  "ok": true,
  "message": "PDF processed successfully",
  "traceId": "uuid",
  "documentId": 1,
  "extractRunId": 2,
  "textLength": 1200,
  "matchResult": { }
}
```

## Examples
### Example 1: PDF + candidateId + jobId + docType (PowerShell)
```powershell
$uri = "http://localhost:18080/api/pipeline/ingest-pdf-and-match"
$formData = @{
  candidateId = "test_candidate_001"
  jobId = "Java Backend Engineer"
  docType = "candidate_resume"
  file = Get-Item "samples\resume.pdf"
}
Invoke-RestMethod -Uri $uri -Method Post -Form $formData
```

### Example 2: jobId omitted (matchResult=null)
```powershell
$uri = "http://localhost:18080/api/pipeline/ingest-pdf-and-match"
$formData = @{
  candidateId = "test_candidate_002"
  docType = "resume"
  file = Get-Item "samples\resume.pdf"
}
Invoke-RestMethod -Uri $uri -Method Post -Form $formData
```

## Notes
- If the uploaded file is not a PDF, the API returns `ok=false` with an error message.
- If text extraction is too short (< 50 chars), the API returns `ok=false` and suggests a scanned PDF.
- The Extract service runs at `http://localhost:5000`.
