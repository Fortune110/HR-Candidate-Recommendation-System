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
