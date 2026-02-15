# ML Training Dataset Export

## Overview

This feature provides API endpoints to export training datasets for machine learning model training. The data is sourced from the `ml_training_examples_v1` SQL VIEW.

## Database View

### View Name: `ml_training_examples_v1`

**Purpose**: Export training examples with job-related features and labels.

**Columns**:
- `job_id` (bigint): Job identifier (required for filtering)
- `candidate_id` (text): Candidate identifier
- `history_id` (bigint): Stage history record ID
- `label` (int): Training label (1 for HIRED, 0 for REJECTED, NULL for other stages)
- `final_stage` (text): Final stage value ('hired', 'rejected', or other)
- `match_score` (numeric): Overall match score (0-1)
- `overlap_score` (numeric): Weighted Jaccard overlap score
- `gap_penalty` (numeric): Penalty for missing high-weight tags
- `bonus_score` (numeric): Bonus for unique strengths
- `skill_match_count` (int): Number of matched skills
- `year_diff` (numeric): Year difference (placeholder, currently NULL)
- `risk_score` (numeric): Risk score (placeholder, currently NULL)
- `stage_changed_at` (timestamptz): Stage change timestamp
- `match_created_at` (timestamptz): Match result creation timestamp
- `reason_code` (varchar): Reason code for stage change

**Label Calculation**:
- `final_stage = 'hired'` → `label = 1`
- `final_stage = 'rejected'` → `label = 0`
- Other `final_stage` values → `label = NULL` (not included in training)

**Filtering**: Only includes records where `job_id IS NOT NULL`.

## API Endpoint

### GET /api/ml/training-examples

**Description**: Export training examples in CSV or JSON format.

**Query Parameters**:
- `jobId` (optional, Long): Filter by job ID. If not provided, returns all training examples.
- `format` (optional, String): Output format. Default: `csv`. Allowed values: `csv`, `json`.

**Response**:
- CSV format: Returns CSV file with header row, Content-Type: `text/csv`
- JSON format: Returns JSON array, Content-Type: `application/json`

**Examples**:

#### 1. Export CSV for specific job

```bash
curl -X GET "http://localhost:18080/api/ml/training-examples?jobId=123&format=csv" \
  -H "Accept: text/csv" \
  -o training_examples.csv
```

#### 2. Export JSON for specific job

```bash
curl -X GET "http://localhost:18080/api/ml/training-examples?jobId=123&format=json" \
  -H "Accept: application/json"
```

#### 3. Export CSV for all jobs

```bash
curl -X GET "http://localhost:18080/api/ml/training-examples?format=csv" \
  -H "Accept: text/csv" \
  -o training_examples_all.csv
```

#### 4. Export JSON for all jobs

```bash
curl -X GET "http://localhost:18080/api/ml/training-examples?format=json" \
  -H "Accept: application/json"
```

## Local Verification Steps

### 1. Start the Application

```powershell
cd talent-archive-core
docker compose up -d postgres

cd ..\resume-blueprint\resume-blueprint-api
.\mvnw.cmd spring-boot:run
```

### 2. Verify Database Migration

The Flyway migration `V7__ml_training_view.sql` should create the VIEW automatically on startup. Verify:

```sql
-- Connect to database
psql "postgresql://rb_user:rb_password@localhost:55434/resume_blueprint_db"

-- Check if view exists
\dv ml_training_examples_v1

-- View structure
\d ml_training_examples_v1

-- Test query
SELECT * FROM ml_training_examples_v1 LIMIT 10;
```

### 3. Create Test Data

To test the API, you need to create test data with `job_id` and `final_stage` values:

```bash
# Create a candidate with HIRED stage for job_id=123
curl -X PATCH "http://localhost:18080/api/candidates/test_candidate_001/stage" \
  -H "Content-Type: application/json" \
  -d '{
    "toStage": "hired",
    "changedBy": "hr_user_001",
    "note": "Test hired for ML training",
    "reasonCode": null,
    "jobId": 123,
    "force": false
  }'

# Create a candidate with REJECTED stage for job_id=123
curl -X PATCH "http://localhost:18080/api/candidates/test_candidate_002/stage" \
  -H "Content-Type: application/json" \
  -d '{
    "toStage": "rejected",
    "changedBy": "hr_user_001",
    "note": "Test rejected for ML training",
    "reasonCode": "TECH_MISMATCH",
    "jobId": 123,
    "force": false
  }'
```

### 4. Test API Endpoint

#### Test CSV Export

```bash
# Export CSV for job_id=123
curl -X GET "http://localhost:18080/api/ml/training-examples?jobId=123&format=csv" \
  -H "Accept: text/csv" \
  -v

# Expected: 200 OK, Content-Type: text/csv, header with columns, data rows
```

#### Test JSON Export

```bash
# Export JSON for job_id=123
curl -X GET "http://localhost:18080/api/ml/training-examples?jobId=123&format=json" \
  -H "Accept: application/json" \
  -v

# Expected: 200 OK, Content-Type: application/json, JSON array with objects
```

#### Test Empty Result

```bash
# Export for non-existent job_id
curl -X GET "http://localhost:18080/api/ml/training-examples?jobId=99999&format=csv" \
  -H "Accept: text/csv" \
  -v

# Expected: 200 OK, empty CSV (only header row if data exists, or empty)
```

### 5. Run Integration Tests

```powershell
cd resume-blueprint\resume-blueprint-api
.\mvnw.cmd test -Dtest=MLTrainingControllerIntegrationTest
```

**Expected**: All tests pass, verifying:
- CSV export returns 200 with correct headers and fields
- JSON export returns 200 with valid JSON structure
- API works with and without jobId filter
- Empty results are handled correctly

## CSV Format Example

```csv
job_id,candidate_id,history_id,label,final_stage,match_score,overlap_score,gap_penalty,bonus_score,skill_match_count,year_diff,risk_score,stage_changed_at,match_created_at,reason_code
123,test_candidate_001,1,1,hired,0.85,0.75,0.10,0.05,15,,,2024-01-01 10:00:00+00,2024-01-01 09:00:00+00,
123,test_candidate_002,2,0,rejected,0.65,0.60,0.15,0.02,8,,,2024-01-01 11:00:00+00,2024-01-01 09:30:00+00,TECH_MISMATCH
```

## JSON Format Example

```json
[
  {
    "job_id": 123,
    "candidate_id": "test_candidate_001",
    "history_id": 1,
    "label": 1,
    "final_stage": "hired",
    "match_score": 0.85,
    "overlap_score": 0.75,
    "gap_penalty": 0.10,
    "bonus_score": 0.05,
    "skill_match_count": 15,
    "year_diff": null,
    "risk_score": null,
    "stage_changed_at": "2024-01-01T10:00:00Z",
    "match_created_at": "2024-01-01T09:00:00Z",
    "reason_code": null
  },
  {
    "job_id": 123,
    "candidate_id": "test_candidate_002",
    "history_id": 2,
    "label": 0,
    "final_stage": "rejected",
    "match_score": 0.65,
    "overlap_score": 0.60,
    "gap_penalty": 0.15,
    "bonus_score": 0.02,
    "skill_match_count": 8,
    "year_diff": null,
    "risk_score": null,
    "stage_changed_at": "2024-01-01T11:00:00Z",
    "match_created_at": "2024-01-01T09:30:00Z",
    "reason_code": "TECH_MISMATCH"
  }
]
```

## Notes

1. **Placeholder Fields**: `year_diff` and `risk_score` are currently NULL placeholders. These can be extended in future migrations to calculate actual values.

2. **Match Data**: The VIEW joins to the latest match result for each candidate. If a candidate has no match results, match-related fields will be 0 or NULL.

3. **Job Filtering**: Only records with `job_id IS NOT NULL` are included in the VIEW. This ensures data quality for training datasets.

4. **Label Calculation**: Only `HIRED` (label=1) and `REJECTED` (label=0) stages are used for training. Other stages have label=NULL and can be filtered out during training.

5. **CSV Encoding**: CSV output uses UTF-8 encoding and properly escapes commas, quotes, and newlines.
