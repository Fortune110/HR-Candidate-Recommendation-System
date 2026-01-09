# spaCy + SkillNER Integration Guide

This document explains how to integrate the Python extraction service (spaCy + SkillNER) into the 4-box framework.

## Architecture Overview

```
┌─────────────────┐
│  Resume/JD Text │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ Box 1: Extract          │
│ - spaCy NER             │
│ - SkillNER              │
│ - Python Service (5000) │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Box 2: Normalize        │
│ - Baseline Dictionary   │
│ - rb_baseline_term      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Box 3: Tagging          │
│ - Hard/Soft Tags        │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Box 4: Match            │
│ - Score Calculation     │
│ - Missing Tags          │
└─────────────────────────┘
```

## Setup Steps

### 1. Start Services

```bash
cd talent-archive-core
docker-compose up -d
```

This starts:
- PostgreSQL (port 55434)
- Extraction service (port 5000)

### 2. Verify Extraction Service

```bash
curl http://localhost:5000/health
```

Expected response:
```json
{"status": "ok", "models_loaded": true}
```

### 3. Run Demo with spaCy Extraction

```bash
cd talent-archive-core
./bin/run_demo_spacy.sh
```

Or with custom text:
```bash
./bin/run_demo_spacy.sh "Your resume text here" "Your JD text here"
```

## Integration Points

### Java API Integration

The Spring Boot API includes:

- **ExtractController** (`/api/extract`): HTTP endpoint for extraction
- **ExtractService**: Business logic layer
- **SpacyExtractorClient**: HTTP client for Python service

Example usage:
```bash
curl -X POST http://localhost:18080/api/extract \
  -H "Content-Type: application/json" \
  -d '{
    "documentId": 1,
    "text": "Skilled in Python and Java...",
    "docType": "RESUME"
  }'
```

### SQL Script Integration

The `run_demo_spacy.sh` script:
1. Calls Python extraction service via HTTP
2. Parses JSON response
3. Generates SQL with extracted entities
4. Executes 4-box pipeline (Normalize → Tagging → Match)

## Data Flow

### 1. Extraction (Box 1)

**Input:** Raw resume/JD text

**Process:**
- Python service extracts entities using spaCy + SkillNER
- Returns structured JSON with canonical format

**Output:**
```json
{
  "entities": [
    {
      "canonical": "skill/python",
      "evidence": "Skilled in Python...",
      ...
    }
  ]
}
```

### 2. Normalization (Box 2)

**Process:**
- Filter entities by `rb_baseline_term` table
- Only keep entities that exist in baseline dictionary

**SQL:**
```sql
resume_norm as (
  select distinct e.canonical
  from resume_extracted_evidence e
  join rb_baseline_term t
    on t.canonical = e.canonical
   and t.status = 'active'
)
```

### 3. Tagging (Box 3)

**Process:**
- Group tags by type (hard/soft)
- Hard: `degree/*`, `exp/*`
- Soft: `skill/*`

### 4. Matching (Box 4)

**Process:**
- Compare resume tags vs JD tags
- Calculate match score
- Identify missing tags

## Evidence Tracking

Each extracted entity includes:
- **hit**: Original text matched
- **canonical**: Normalized canonical tag
- **via**: Extraction source (`spacy+skillner`)
- **evidence**: Context around the entity (for traceability)

Example:
```json
{
  "hit": "Python3",
  "canonical": "skill/python",
  "via": "spacy+skillner",
  "evidence": "Skilled in Python3; 3 years experience"
}
```

This allows answering: "Why did you extract this skill?" → "Because the resume says: 'Skilled in Python3...'"

## Fallback Behavior

If the extraction service is unavailable:
- `run_demo_spacy.sh` falls back to `run_demo.sh` (SQL-based extraction)
- Java API returns error or empty result

## Testing

### Test Extraction Service

```bash
curl -X POST http://localhost:5000/extract \
  -H "Content-Type: application/json" \
  -d '{
    "text": "John Smith worked at Google from 2020 to 2023. Skills: Python, Java, Docker.",
    "doc_type": "RESUME"
  }'
```

### Test Full Pipeline

```bash
# Start services
docker-compose up -d

# Run demo
./bin/run_demo_spacy.sh

# Check results in database
psql "postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db" \
  -c "SELECT id, result_json FROM rb.rb_analysis_run ORDER BY id DESC LIMIT 1;"
```

## Troubleshooting

### Service Not Starting

Check logs:
```bash
docker-compose logs extract-service
```

### Model Download Issues

If spaCy model fails to download:
```bash
docker exec -it resume_blueprint_extract python -m spacy download en_core_web_sm
```

### Port Conflicts

If port 5000 is in use, update `docker-compose.yml`:
```yaml
ports:
  - "5001:5000"  # Change host port
```

And update `EXTRACT_SERVICE_URL`:
```bash
export EXTRACT_SERVICE_URL=http://localhost:5001
```

## Next Steps

1. **Expand Skill Dictionary**: Add more tech skills to SkillNER
2. **NER Label Mapping**: Map spaCy NER labels to baseline terms
3. **Confidence Scoring**: Improve score calculation based on entity type
4. **Batch Processing**: Optimize for large-scale extraction
