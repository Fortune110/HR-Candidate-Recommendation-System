# Quick Start Guide

## Current Status

- PostgreSQL database: port 55434 (Docker)
- Extract Service (Python): port 5000
- Spring Boot API: port 18080

---

## Step 1 — Start the Backend

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System/resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
```

Wait for:
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

---

## Step 2 — Verify

```bash
curl -s http://localhost:18080/api/extract/health
```

Expected:
```json
{"runId":0,"message":"Extraction service is available"}
```

---

## Step 3 — Run E2E Tests

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System
bash requests/e2e_smoke.sh
```

---

## Background Mode

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System/resume-blueprint/resume-blueprint-api
nohup ./mvnw spring-boot:run > /tmp/rb-api.log 2>&1 &
tail -f /tmp/rb-api.log
```

---

## Troubleshooting

**Database connection error:**
```bash
# Check containers
cd ~/Desktop/HR-Candidate-Recommendation-System/talent-archive-core
docker compose ps

# Verify DB config in application.yml
url: jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db
username: rb_user
password: rb_password
```

**Port 18080 in use:**
```bash
lsof -i :18080
kill -9 <PID>
```
