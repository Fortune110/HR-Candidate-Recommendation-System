# Project Scan Report

## Project Overview

**Project Name:** HR Candidate Recommendation System  
**Primary Tech Stack:** Spring Boot 4.0.1, Java 21, PostgreSQL 16, Python (Flask)  
**Scan Date:** 2024-01-01

---

## 1. Spring Boot Application Configuration

### Startup Options
- **Maven Wrapper:** `mvnw.cmd` (Windows) / `mvnw` (Unix)
- **Main Class:** `com.fortune.resumeblueprint.ResumeBlueprintApiApplication`
- **Startup Command:**
  ```powershell
  cd resume-blueprint\resume-blueprint-api
  .\mvnw.cmd spring-boot:run
  ```
  Or:
  ```powershell
  .\mvnw.cmd clean package
  java -jar target\resume-blueprint-api-0.0.1-SNAPSHOT.jar
  ```

### Application Port
- **Primary Port:** `18080` (configured in `application.yml`)
- **Config File:** `resume-blueprint/resume-blueprint-api/src/main/resources/application.yml`

### Database Configuration
- **JDBC URL:** `jdbc:postgresql://127.0.0.1:55434/resume_blueprint_db`
- **Username:** `rb_user`
- **Password:** `rb_password`
- **Database Name:** `resume_blueprint_db`
- **Port:** `55434`

### Flyway Migrations
- **Enabled:** Yes
- **Location:** `classpath:db/migration`
- **Migration Files:**
  - `V1__blueprint_core.sql`
  - `V1__rb_core.sql`
  - `V2__baseline.sql`
  - `V2__rb_baseline.sql`
  - `V3__rb_review.sql`
  - `V4__success_profile_and_match.sql`
  - `V5__candidate_pipeline_stage.sql`

---

## 2. Docker Compose Configuration

### File Location
- `talent-archive-core/docker-compose.yml`

### PostgreSQL Service
- **Container Name:** `resume_blueprint_postgres`
- **Image:** `postgres:16`
- **Port Mapping:** `55434:5432`
- **Database Name:** `resume_blueprint_db`
- **Username:** `rb_user`
- **Password:** `rb_password`
- **Volume:** `rb_pgdata`

### Extract Service (Python)
- **Container Name:** `resume_blueprint_extract`
- **Port Mapping:** `5000:5000`
- **Health Check:** `GET http://localhost:5000/health`
- **Build Context:** `./extract-service`

### Startup Command
```powershell
cd talent-archive-core
docker-compose up -d postgres
docker-compose up -d extract-service
```

---

## 3. API Endpoint Inventory

### 3.1 Resume Controller
**Base Path:** `/api/resumes`

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|--------------|----------|
| POST | `/api/resumes` | Resume ingestion | `ResumeIngestRequest` | `ResumeIngestResponse` (documentId) |
| GET | `/api/resumes/{documentId}` | Resume detail | - | `ResumeDocumentResponse` |
| GET | `/api/resumes?limit=50&offset=0` | Resume list | - | `List<ResumeSummaryResponse>` |
| POST | `/api/resumes/{documentId}/analyze/bootstrap` | Bootstrap analysis | `AnalyzeRequest` | `AnalyzeResponse` |
| POST | `/api/resumes/{documentId}/analyze/baseline` | Baseline analysis | `AnalyzeRequest` + `baselineSetId` param | `AnalyzeResponse` |

### 3.2 Extract Controller
**Base Path:** `/api/extract`

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|--------------|----------|
| POST | `/api/extract` | Entity extraction | `ExtractRequest` | `ExtractResponse` (runId, message) |
| GET | `/api/extract/health` | Health check | - | `ExtractResponse` (runId: 0, message) |

### 3.3 Match Controller
**Base Path:** `/api/match`

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|--------------|----------|
| POST | `/api/match` | Match query | `MatchRequest` | `MatchResponse` (matchRunId, matches[]) |
| GET | `/api/match/{matchRunId}` | Match run detail | - | `MatchRunResponse` |

### 3.4 Baseline Controller
**Base Path:** `/api/baseline`

| Method | Path | Purpose | Request Params | Response |
|--------|------|---------|----------------|----------|
| POST | `/api/baseline/build` | Build baseline | `lastN=50`, `minCount=2` | `BaselineBuildResponse` |

### 3.5 Success Profile Controller
**Base Path:** `/api/success-profiles`

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|--------------|----------|
| POST | `/api/success-profiles/import` | Import success profiles | `ImportProfileRequest` | `ImportProfileResponse` (profileId, message) |

---

## 4. Swagger/OpenAPI Status

**Status:** Enabled

- Dependency: `springdoc-openapi-starter-webmvc-ui`
- Access URLs:
  - `/swagger-ui/index.html`
  - `/v3/api-docs`

---

## 5. Actuator Status

**Status:** Enabled

- Dependency: `spring-boot-starter-actuator`
- Endpoints:
  - `/actuator/health`
  - `/actuator/info`

---

## 6. Query Endpoint Status

**Status:** GET query endpoints are available

### Added Endpoints
- `GET /api/resumes/{documentId}` for resume detail
- `GET /api/resumes?limit=50&offset=0` for resume list
- `GET /api/match/{matchRunId}` for match results

### Impact
- Data written by POST endpoints can be verified directly via GET endpoints.

---

## 7. Golden Path Recommendations

Based on the current API set, the following flows are recommended for verification:

### Path 1: Resume Processing
1. **POST /api/resumes** → obtain `documentId`
2. **POST /api/extract** → use `documentId` to extract entities → obtain `runId`
3. **POST /api/match** → use `documentId` to match → obtain `matchRunId` and `matches[]`

### Path 2: Success Profile Matching (requires data import)
1. **POST /api/success-profiles/import** → import profiles → obtain `profileId`
2. **POST /api/resumes** → ingest resume → obtain `documentId`
3. **POST /api/match** → match → validate `matches` is non-empty

### Path 3: Baseline Build
1. **POST /api/baseline/build** → obtain `baselineSetId`
2. **POST /api/resumes/{documentId}/analyze/baseline?baselineSetId={baselineSetId}** → run baseline analysis

---

## 8. Test Data Files

### Available Test Data
- `samples/resume_001.txt` - Standard test resume (Alex Chen)
- `samples/jd_001.txt` - Standard test job description

---

## 9. Configuration Consistency

### Database Alignment
- **Application Config:** `resume_blueprint_db` / `rb_user` / `rb_password` / port `55434`
- **Docker Compose:** `resume_blueprint_db` / `rb_user` / `rb_password` / port `55434`
- **Status:** Aligned

---

## 10. Dependency Services

### Extract Service (Python)
- **Status:** Optional (extract API checks availability)
- **Health Check:** `GET http://localhost:5000/health`
- **If Unavailable:** Extract API returns a warning but does not block other functionality.

### OpenAI API
- **Config:** `OPENAI_API_KEY` environment variable
- **Model:** `gpt-4o-mini` (default, override with `OPENAI_MODEL`)
- **Usage:** Analyze API (bootstrap/baseline)

---

## 11. Testing Framework Status

### JUnit 5
- **Status:** Configured
- **Test Dependencies:**
  - `spring-boot-starter-webmvc-test`
  - `spring-boot-starter-validation-test`
  - `spring-boot-starter-flyway-test`

### Testcontainers
- **Status:** Not configured
- **Reason:** No dependency found and not enforced

### MockMvc
- **Status:** Available via `@AutoConfigureMockMvc`

---

## 12. Summary

### Strengths
- Clear API structure with separated responsibilities
- Flyway-based database versioning
- Health check endpoint (`/api/extract/health`)
- Testing framework configured

### Gaps
- Testcontainers not configured for isolated integration testing

### Testing Recommendations
1. Prefer the Golden Path 1 flow for E2E validation.
2. Ensure the database is accessible for integration tests.
3. When Extract Service is unavailable, mark related checks as WARN rather than FAIL.

---

**Report Generated:** 2024-01-01  
**Scan Method:** Manual code review + automated scan
