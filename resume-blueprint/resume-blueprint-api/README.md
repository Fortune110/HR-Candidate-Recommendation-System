# Resume Blueprint API (rb_)

Goal: Convert resume text -> traceable analysis run -> tags -> gradually accumulate baseline (term dictionary), subsequent resumes prioritize alignment with baseline.

## Data Flow
1. POST /api/resumes
   - Save rb_document (original resume text)
2. POST /api/resumes/{documentId}/analyze/bootstrap
   - LLM freely extracts keywords: used for cold-start term accumulation
   - Write to rb_run + rb_extracted_tag + rb_tag_evidence
3. POST /api/baseline/build?lastN=50&minCount=2
   - Aggregate tags from historical runs to generate baseline_set + baseline_term
4. POST /api/resumes/{documentId}/analyze/baseline?baselineSetId=...
   - LLM can only select selected_terms from baseline
   - new_terms enter pending (subsequent manual confirmation/mapping)

## Table Design (all rb_ prefix to avoid conflicts with old projects)
- rb_document: Resume text
- rb_run: One analysis run (model/prompt version/configuration traceable)
- rb_canonical_tag: Normalized tags (INTERNAL/ESCO/...)
- rb_extracted_tag: Tag results from run (score)
- rb_tag_evidence: Tag evidence
- rb_baseline_set / rb_baseline_term / rb_baseline_alias: Baseline term dictionary (versioned) and alias mappings

## Directory Structure
- api/: Controller + DTO
- service/: Business logic (ingest/analyze/build baseline)
- repo/: SQL access (JdbcTemplate)
- infra/: Replaceable LLM implementation (currently stub, will integrate OpenAI later)

## PDF Upload Feature

### Swagger UI (Recommended for Developers)
After starting the application, access Swagger UI for API testing and documentation:
- Access URL: `http://localhost:18080/swagger-ui/index.html`
- Find `PdfPipelineController` -> `POST /api/pipeline/ingest-pdf-and-match`
- Click "Try it out", fill in parameters, select PDF file, click "Execute"

### Upload Page (Recommended for Non-Technical Users)
Demo upload portal, no command line or Postman required:
- Access URL: `http://localhost:18080/upload`
- Fill in candidateId (or use auto-generated), optionally fill in jobId and docType
- Select PDF file, click "Upload and Process"
- View upload results, including traceId, textLength and matchResult (if jobId is provided)

**Feature Description:**
- `candidateId`: Required, will auto-generate UUID if left empty
- `docType`: Optional, default is `candidate_resume`, supports: candidate_resume, resume, jd, job_description, job
- `jobId`: Optional, if provided will perform matching analysis and return matchResult
- `file`: Required, PDF file, max 10MB, only supports text-based PDF (scanned document OCR not implemented)

**Error Messages:**
- Non-PDF file: Will show "Invalid file type; expected a PDF upload."
- Unsupported docType: Will show "Unsupported docType"
- Scanned document (textLength < 50): Will show "Extracted text is too short"
- extract-service not started: Will fail at extract step and show corresponding error