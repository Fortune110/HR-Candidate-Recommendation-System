# Delivery Checklist

## Services Overview

| Service | Port | Start Command |
|---------|------|---------------|
| PostgreSQL (Docker) | 55434 | `docker compose up -d` (in `talent-archive-core/`) |
| Python Extract Service | 5000 | `python extract_service.py` (in `talent-archive-core/extract-service/`) |
| Spring Boot API | 18080 | `./mvnw spring-boot:run` (in `resume-blueprint/resume-blueprint-api/`) |
| React Frontend | 5173 | `npm run dev` (in `frontend/`) |

---

## 1. Startup

### Docker (PostgreSQL + Extract Service)

```bash
cd talent-archive-core
docker compose up -d
```

### Spring Boot API

```bash
cd resume-blueprint/resume-blueprint-api
./mvnw spring-boot:run
```

### Frontend

```bash
cd frontend
npm run dev
```

---

## 2. API Endpoints

| Method | Path | Purpose | Priority |
|--------|------|---------|----------|
| GET | `/api/extract/health` | Health check | Critical |
| POST | `/api/resumes` | Ingest resume text | Critical |
| POST | `/api/resumes/file` | Ingest resume file (PDF/DOCX) | Critical |
| POST | `/api/resumes/{id}/analyze/bootstrap` | Extract skill tags | Critical |
| POST | `/api/jd/analyze` | Parse job description | Core |
| GET | `/api/recommend` | Rank candidates by JD | Core |
| POST | `/api/match` | Match resume vs cohort | Optional |
| POST | `/api/baseline/build` | Build skill baseline | Optional |
| POST | `/api/success-profiles/import` | Import success profiles | Optional |

---

## 3. Golden Path

```bash
# 1. Ingest a resume
curl -s -X POST http://localhost:18080/api/resumes \
  -H "Content-Type: application/json" \
  -d '{"candidateId":"test-001","text":"Senior Java engineer with 5+ years..."}' \
  | python3 -m json.tool
# → {"documentId": 1}

# 2. Extract skills
curl -s -X POST http://localhost:18080/api/resumes/1/analyze/bootstrap \
  | python3 -m json.tool
# → {"runId":..., "keywords":[...]}

# 3. Analyse a JD
curl -s -X POST http://localhost:18080/api/jd/analyze \
  -H "Content-Type: application/json" \
  -d '{"text":"We are looking for a senior Java engineer..."}' \
  | python3 -m json.tool
# → {"jdId":2, "requiredSkills":[...]}

# 4. Get recommendations
curl -s -G http://localhost:18080/api/recommend \
  --data-urlencode "jdId=2" --data-urlencode "limit=10" \
  | python3 -m json.tool
# → {"jdId":2, "total":1, "results":[...]}
```

---

## 4. Key Files Changed / Added

| File | Description |
|------|-------------|
| `V6__jd.sql` | Job description table |
| `V7__rb_schema_views.sql` | Bridge views for rb-schema tables |
| `JdService.java` | JD parsing via OpenAI Responses API |
| `JdController.java` | `POST /api/jd/analyze` |
| `JdRepo.java` | JD persistence + findById |
| `RecommendController.java` | `GET /api/recommend` |
| `RecommendResponse.java` | Recommend DTO |
| `frontend/` | React + Vite + Tailwind frontend |

---

## 5. Troubleshooting Order

1. Is PostgreSQL running? → `docker compose ps`
2. Is the API healthy? → `curl http://localhost:18080/api/extract/health`
3. Is the extract service up? → `curl http://127.0.0.1:5000/health`
4. Check API logs → `/tmp/rb-app.log`
5. Check DB tables → `psql ... -c "\dt rb_*"`

---

## 6. Known Limitations

- JD skill extraction requires an OpenAI API key (`OPENAI_API_KEY` env var). Without it, `requiredSkills` returns empty but the endpoint still works.
- Resume skill extraction uses spaCy NER + keyword matching. Results depend on extract service availability.
- Match scores are 0.0 if no skills have been extracted for a candidate yet (run bootstrap first).
