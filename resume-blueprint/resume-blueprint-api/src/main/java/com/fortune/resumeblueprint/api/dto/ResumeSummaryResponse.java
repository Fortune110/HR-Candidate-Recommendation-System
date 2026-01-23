package com.fortune.resumeblueprint.api.dto;

import java.time.Instant;

public record ResumeSummaryResponse(
        long documentId,
        String candidateId,
        String contentHash,
        Instant createdAt
) {}
