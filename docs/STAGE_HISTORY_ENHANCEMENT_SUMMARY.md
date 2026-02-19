# Candidate Stage History Enhancement Summary

## Overview
Adds `reason_code` and `job_id` to candidate stage history to support downstream training data.

## Key changes
- Migration: `V6__candidate_stage_history_reason_code.sql`
- DTOs: `ChangeStageRequest`, `StageHistoryItem`
- Repository: `CandidateRepo`
- Service: `CandidateService`
- Controller: `CandidateController`

## Example request
```http
PATCH /api/candidates/test_candidate_001/stage
Content-Type: application/json

{
  "toStage": "rejected",
  "changedBy": "hr_user_001",
  "note": "Technical skills mismatch",
  "reasonCode": "TECH_MISMATCH",
  "jobId": 123,
  "force": false
}
```

## Suggested reason codes
- TECH_MISMATCH
- SALARY
- CANDIDATE_DECLINED
- HC_FROZEN
- NO_SHOW
- OTHER
