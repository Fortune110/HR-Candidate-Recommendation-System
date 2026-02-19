# Testing Guide

## Smoke test
Goal: verify the system starts and a core API responds.
```powershell
.\requests\e2e_smoke.ps1
```

## API test checklist
- `GET /api/extract/health` returns 200 with `runId` and `message`
- `POST /api/resumes` returns `documentId > 0`
- `POST /api/extract` returns `runId` and `message` (warn if extract-service is down)
- `POST /api/match` returns `matchRunId` and `matches[]`

## E2E golden path
1. Resume ingestion  
2. Extract  
3. Match  

Expected: HTTP 200 and valid JSON structures for each step.

## Performance expectations (guideline)
- Health check < 100ms
- Resume ingestion < 1s
- Extract < 5s
- Match < 3s

## Environment requirements
- Java 21+
- Maven 3.6+
- Docker Desktop (Windows)
- PostgreSQL 16 (Docker)
- Python 3.11+ (extract-service)
