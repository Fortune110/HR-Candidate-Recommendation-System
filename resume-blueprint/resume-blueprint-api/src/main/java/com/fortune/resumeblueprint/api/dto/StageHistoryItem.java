package com.fortune.resumeblueprint.api.dto;

import java.time.Instant;

public record StageHistoryItem(
        long historyId,
        String candidateId,
        String fromStage,
        String toStage,
        String changedBy,
        String note,
        String reasonCode,                 // reason code (e.g., TECH_MISMATCH, SALARY, CANDIDATE_DECLINED, HC_FROZEN, NO_SHOW, OTHER)
        Long jobId,                        // job_id for tracking which job/position this relates to
        Instant changedAt
) {}
