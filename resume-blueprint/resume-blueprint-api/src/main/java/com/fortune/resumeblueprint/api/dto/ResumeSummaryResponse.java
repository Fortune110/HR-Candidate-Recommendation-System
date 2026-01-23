package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;

public record ResumeSummaryResponse(
        long documentId,
        String entityType,
        String candidateId,
        String contentHash,
        OffsetDateTime createdAt
) {}
