# HR Candidate Recommendation System

![Java](https://img.shields.io/badge/Java-21-orange?logo=openjdk)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-4.0-green?logo=springboot)
![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)
![React](https://img.shields.io/badge/React-19-61DAFB?logo=react)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)

An AI-powered HR candidate recommendation system that parses job descriptions, extracts skills from resumes, and ranks candidates by match score against a success cohort profile.

**GitHub:** https://github.com/Fortune110/HR-Candidate-Recommendation-System

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser                              │
│              React Frontend  :5173                          │
│         (Upload · Candidates · JD Match)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │  /api/* (proxy)
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Spring Boot API  :18080                        │
│  /api/resumes   /api/jd/analyze   /api/recommend            │
│  /api/match     /api/extract      /api/success-profiles     │
└───────────┬──────────────────────┬──────────────────────────┘
            │  HTTP                │  JDBC
            ▼                      ▼
┌───────────────────────┐  ┌──────────────────────────────────┐
│  Python Extract  :5000│  │     PostgreSQL  :55434           │
│  spaCy NER            │  │  Schema: public + rb             │
│  Keyword extraction   │  │  Flyway migrations V1–V7         │
│  PDF / DOCX parsing   │  └──────────────────────────────────┘
└───────────────────────┘
```

---

## Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Frontend | React 19 + Vite + Tailwind CSS v4 | SPA, 3 pages |
| API | Spring Boot 4.0.1 (Java 21) | Spring MVC + WebFlux (WebClient only) |
| Skill Extraction | Python 3 + Flask + spaCy | NER + keyword matching |
| Database | PostgreSQL 16 | JdbcTemplate, no JPA |
| Migrations | Flyway | V1–V7, dual-schema (`public` + `rb`) |
| AI (JD parsing) | OpenAI `gpt-4o-mini` via Responses API | Optional — graceful fallback |
| File parsing | pdfplumber + python-docx | PDF and DOCX support |

---

## Quick Start (Docker)

The fastest way to run everything with a single command:

```bash
# 1. Copy env file and add your OpenAI key (optional — skills still extracted without it)
cp .env.example .env

# 2. Build and start all 4 services
docker compose up --build
```

| Service | URL |
|---------|-----|
| Frontend | http://localhost |
| Spring Boot API | http://localhost:18080 |
| Python Extract | http://localhost:5000 |
| PostgreSQL | `127.0.0.1:55434` |

> First build takes ~5 minutes (Maven + spaCy model download). Subsequent starts are fast.

---

## Local Setup (Manual)

### Prerequisites

- Java 21 JDK
- Python 3.11+
- Node.js 18+
- Docker Desktop (for PostgreSQL)
- _(Optional)_ `OPENAI_API_KEY` for JD skill extraction

### Step 1 — Start PostgreSQL

```bash
cd talent-archive-core
docker compose up -d
```

Verify:
```bash
PGPASSWORD=rb_password psql -h 127.0.0.1 -p 55434 -U rb_user -d resume_blueprint_db -c "SELECT 1;"
```

### Step 2 — Start Python Extract Service

```bash
cd talent-archive-core/extract-service
pip install -r requirements.txt
python extract_service.py
# Running on http://127.0.0.1:5000
```

> **macOS note:** Disable AirPlay Receiver (System Settings → General → AirDrop & Handoff) to free port 5000.

### Step 3 — Start Spring Boot API

```bash
cd resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
# Started on http://localhost:18080
```

To enable JD skill extraction, set your OpenAI key first:
```bash
export OPENAI_API_KEY=sk-...
./mvnw spring-boot:run
```

### Step 4 — Start React Frontend

```bash
cd frontend
npm install
npm run dev
# Running on http://localhost:5173
```

Open http://localhost:5173 in your browser.

---

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/extract/health` | Health check (extract service status) |
| `POST` | `/api/resumes` | Ingest resume text → `documentId` |
| `POST` | `/api/resumes/file` | Ingest resume file (PDF/DOCX) → `documentId` |
| `POST` | `/api/resumes/{id}/analyze/bootstrap` | Extract skill tags from a resume |
| `GET` | `/api/resumes` | List all candidate documents |
| `GET` | `/api/resumes/{id}` | Get a single resume document |
| `POST` | `/api/jd/analyze` | Parse a JD text → skills, level, summary |
| `GET` | `/api/recommend?jdId=X&limit=10` | Rank candidates against a JD |
| `POST` | `/api/match` | Match a resume vs success cohort |
| `GET` | `/api/match/{runId}` | Get a past match result |
| `POST` | `/api/success-profiles/import` | Import success cohort profiles |
| `POST` | `/api/baseline/build` | Build skill baseline vocabulary |

### Quick Example

```bash
# 1. Ingest a resume
curl -s -X POST http://localhost:18080/api/resumes \
  -H "Content-Type: application/json" \
  -d '{"candidateId":"jane-doe","text":"Senior Java engineer, 6 years Spring Boot, Kafka, PostgreSQL..."}' \
  | python3 -m json.tool
# → {"documentId": 1}

# 2. Extract skills
curl -s -X POST http://localhost:18080/api/resumes/1/analyze/bootstrap \
  | python3 -m json.tool
# → {"runId":..., "keywords":[{"term":"java","score":0.9,...},...]}

# 3. Analyse a job description
curl -s -X POST http://localhost:18080/api/jd/analyze \
  -H "Content-Type: application/json" \
  -d '{"text":"We are looking for a senior Java engineer with Spring Boot and Kafka experience."}' \
  | python3 -m json.tool
# → {"jdId":2,"requiredSkills":["java","spring-boot","kafka"],"level":"senior",...}

# 4. Get ranked candidates
curl -s -G http://localhost:18080/api/recommend \
  --data-urlencode "jdId=2" --data-urlencode "limit=5" \
  | python3 -m json.tool
# → {"jdId":2,"total":1,"results":[{"candidateId":"jane-doe","score":0.72,...}]}
```

---

## Database Schema

```
public schema (application tables)
───────────────────────────────────────────────────────
rb_document          resume documents (entity_id, content_text)
rb_run               analysis runs per document
rb_canonical_tag     normalised skill/tag vocabulary
rb_extracted_tag     tags extracted per run (score, weight)
rb_tag_evidence      evidence snippets for each tag
rb_baseline_set      skill baseline configurations
rb_baseline_term     terms in each baseline
rb_job_description   parsed JD records (skills, level, summary)
rb_candidate         candidate records
rb_candidate_stage_history  pipeline stage tracking

rb schema (success-profile / matching tables — bridged via V7 views)
───────────────────────────────────────────────────────
rb_success_profile   cohort profiles (internal_employee / external_success)
rb_success_profile_tag  tags per cohort profile with weights
rb_match_run         a matching run (resume × cohort)
rb_match_result      scores per match run (overlap, gap, bonus)
rb_resume_project    project blocks extracted from a resume
rb_resume_project_tag  tags per project block
```

---

## Project Structure

```
HR-Candidate-Recommendation-System/
├── frontend/                        # React + Vite + Tailwind
│   └── src/pages/
│       ├── UploadPage.jsx           # Resume upload + skill badge display
│       ├── CandidatesPage.jsx       # Candidate list
│       └── RecommendPage.jsx        # JD input → ranked recommendations
├── resume-blueprint/
│   └── resume-blueprint-api/        # Spring Boot API (port 18080)
│       └── src/main/
│           ├── java/.../api/        # Controllers + DTOs
│           ├── java/.../service/    # JdService, MatchService, ResumeService
│           ├── java/.../repo/       # JdbcTemplate repositories
│           └── resources/db/migration/  # Flyway V1–V7
└── talent-archive-core/
    ├── extract-service/             # Python Flask (port 5000)
    │   └── extract_service.py       # spaCy NER + PDF/DOCX parsing
    └── sql/                         # Seed data scripts
```

---

## Known Limitations & Roadmap

| # | Limitation | Planned Fix |
|---|-----------|-------------|
| 1 | Match score ignores seniority level | Use JD `level` field to filter/weight cohort profiles |
| 2 | JD parsing requires OpenAI API key (resume analysis has stub fallback) | Add local LLM fallback (Ollama) for JD parsing |
| 3 | No authentication | Add Spring Security + JWT |
| 4 | Recommend API loads all documents in memory | Add pagination + pre-computed score cache |
