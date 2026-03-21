# Starting the Application

## Prerequisites

- Java 21 JDK installed
- Maven wrapper (`./mvnw`) available
- PostgreSQL running on port 55434 (via Docker Compose)
- Python extract service running on port 5000

---

## Start the Backend

Open a terminal and run:

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System/resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
```

First startup may take 1–2 minutes (dependency download + compilation).

**Success indicator:**
```
Started ResumeBlueprintApiApplication in X.XXX seconds
```

---

## Verify

In a new terminal:

```bash
curl -s http://localhost:18080/api/extract/health
```

Expected:
```json
{"runId":0,"message":"Extraction service is available"}
```

---

## Common Errors

**Database connection refused:**
```
org.postgresql.util.PSQLException: Connection refused
```
→ Check Docker containers: `docker compose ps` (in `talent-archive-core/`)

**Port already in use:**
```
Web server failed to start. Port 18080 was already in use.
```
→ Find the process: `lsof -i :18080`, then `kill <PID>`

**Flyway migration failed:**
```
FlywayException: ...
```
→ Verify DB config: port `55434`, db `resume_blueprint_db`, user `rb_user`

---

## Run E2E Tests

```bash
cd ~/Desktop/HR-Candidate-Recommendation-System
bash requests/e2e_smoke.sh
```
