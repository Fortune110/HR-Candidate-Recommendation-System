# Delivery Checklist

## Deliverables
- Scripts: `requests/e2e_smoke.ps1`, `requests/api.http`
- Docs: `docs/TESTING.md`, `docs/PROJECT_SCAN_REPORT.md`, `docs/DELIVERY_CHECKLIST.md`
- Test data: `samples/resume_001.txt`, `samples/jd_001.txt`

## Start services
```powershell
cd talent-archive-core
docker-compose up -d postgres
docker-compose up -d extract-service
```

## Start Spring Boot
```powershell
cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

## Run tests
```powershell
.\requests\e2e_smoke.ps1
```

## Acceptance checks
- Health endpoint returns 200
- Resume ingestion returns a documentId
- Extract/match return valid response structures
- Flyway migrations complete without errors
