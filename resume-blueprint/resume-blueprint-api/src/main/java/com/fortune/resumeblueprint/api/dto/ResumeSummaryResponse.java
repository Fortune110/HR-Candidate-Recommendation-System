package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;

public record ResumeSummaryResponse(
        long documentId,
        String candidateId,
        String entityType,
        String contentHash,
        OffsetDateTime createdAt
) {}
