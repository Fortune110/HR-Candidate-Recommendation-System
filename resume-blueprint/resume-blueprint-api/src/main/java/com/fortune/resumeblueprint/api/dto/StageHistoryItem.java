package com.fortune.resumeblueprint.api.dto;

import java.time.Instant;

public record StageHistoryItem(
        long historyId,
        String candidateId,
        String fromStage,
        String toStage,
        String changedBy,
        String note,
        Instant changedAt
) {}
