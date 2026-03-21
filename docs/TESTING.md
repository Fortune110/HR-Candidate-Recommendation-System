# Testing Acceptance Criteria

## Overview

This document defines the testing acceptance criteria for the HR Candidate Recommendation System, covering Smoke Tests, API Tests, and E2E Tests.

---

## 1. Smoke Test

**Goal:** Verify that the system starts and core functionality is reachable.

**Acceptance criteria:**
- Service starts successfully
- Health check endpoint returns 200 OK
- Database connection is healthy
- At least one core API responds correctly

**Run:**
```bash
bash requests/e2e_smoke.sh
```

**Pass conditions:**
- `[PASS] Health Check`
- `[PASS] Resume Ingestion`

---

## 2. API Tests

### 2.1 Health Check

**Endpoint:** `GET /api/extract/health`

**Criteria:**
- HTTP 200
- Response contains `runId` (number) and `message` (non-empty string)

```json
{"runId": 0, "message": "Extraction service is available"}
```

### 2.2 Resume Ingestion

**Endpoint:** `POST /api/resumes`

**Request:**
```json
{"candidateId": "test-001", "text": "Java developer with 5 years experience..."}
```

**Criteria:**
- HTTP 200
- Response contains `documentId` > 0

### 2.3 Extract API

**Endpoint:** `POST /api/extract`

**Criteria:**
- HTTP 200
- Response contains `runId`, `keywords` array

### 2.4 Match API

**Endpoint:** `POST /api/match`

**Criteria:**
- HTTP 200
- Response contains `matchRunId` and `matches` array with `score` values

### 2.5 JD Analysis

**Endpoint:** `POST /api/jd/analyze`

**Criteria:**
- HTTP 200
- Response contains `jdId`, `requiredSkills`, `level`

### 2.6 Recommend API

**Endpoint:** `GET /api/recommend?jdId=<id>&limit=10`

**Criteria:**
- HTTP 200
- Response contains `jdId`, `total`, `results` array

---

## 3. E2E Test — Golden Path

Full pipeline test:

1. **Ingest resume** → `POST /api/resumes` → get `documentId`
2. **Analyse skills** → `POST /api/resumes/{id}/analyze/bootstrap` → get `keywords`
3. **Analyse JD** → `POST /api/jd/analyze` → get `jdId`
4. **Recommend** → `GET /api/recommend?jdId={id}` → get ranked candidates

---

## 4. Performance Criteria

| Endpoint | Max Response Time |
|----------|------------------|
| Health check | < 500ms |
| Resume ingest | < 2s |
| Skill extraction (bootstrap) | < 10s |
| Recommend (10 candidates) | < 5s |

---

## 5. Error Handling

| Scenario | Expected HTTP Status |
|----------|---------------------|
| Missing required field | 400 Bad Request |
| Resource not found | 404 Not Found |
| Server error | 500 Internal Server Error |
