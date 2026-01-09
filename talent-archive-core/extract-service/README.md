# English Extraction Service (spaCy + SkillNER)

Python microservice for Box 1 (Extract) stage of the 4-box framework.

## Features

- **spaCy NER**: Extracts named entities (PERSON, ORG, DATE, GPE, etc.)
- **SkillNER**: Extracts technical skills from resume/JD text
- **Evidence tracking**: Returns context around each extracted entity
- **Canonical format**: Outputs entities in format compatible with `rb_baseline_term` table

## Quick Start

### Using Docker Compose (Recommended)

```bash
cd talent-archive-core
docker-compose up -d extract-service
```

The service will be available at `http://localhost:5000`

### Manual Setup

```bash
cd extract-service
pip install -r requirements.txt
python -m spacy download en_core_web_sm
python extract_service.py
```

## API Endpoints

### POST /extract

Extract entities from English text.

**Request:**
```json
{
  "text": "Skilled in Python3; 3 years experience; Bachelor's degree...",
  "doc_type": "RESUME"
}
```

**Response:**
```json
{
  "entities": [
    {
      "type": "skill",
      "label": "SKILL",
      "text": "Python3",
      "normalized": "python3",
      "canonical": "skill/python3",
      "start": 12,
      "end": 19,
      "evidence": "Skilled in Python3; 3 years experience"
    }
  ],
  "summary": "Extracted 5 skills and 3 named entities from resume",
  "extractor": "spacy+skillner",
  "extractor_version": "1.0"
}
```

### GET /health

Health check endpoint.

## Integration with 4-Box Framework

The extraction service integrates at **Box 1 (Extract)**:

1. **Extract** (this service) → spaCy NER + SkillNER
2. **Normalize** → Enforce baseline dictionary (`rb_baseline_term`)
3. **Tagging** → Group hard/soft tags
4. **Match** → Calculate score and missing tags

## Output Format

Entities are output in canonical format:
- Skills: `skill/{normalized}` (e.g., `skill/python`)
- NER: `ner/{label}/{normalized}` (e.g., `ner/ORG/Google`)

This format is compatible with the `rb_baseline_term.canonical` column.

## Docker Image

The Dockerfile includes:
- Python 3.11
- spaCy with English model (`en_core_web_sm`)
- SkillNER library
- Flask web server

Build manually:
```bash
docker build -t resume-blueprint-extract ./extract-service
```

## Troubleshooting

### Model Not Found

If you see "spaCy English model not found":
```bash
python -m spacy download en_core_web_sm
```

### SkillNER Not Available

The service will fall back to pattern-based skill extraction if SkillNER is not available.

### Port Already in Use

Change the port in `docker-compose.yml` or pass port as argument:
```bash
python extract_service.py 5001
```
