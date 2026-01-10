package com.fortune.resumeblueprint.api.dto;

import java.time.Instant;

public record CandidateResponse(
        String candidateId,
        String stage,
        Instant stageUpdatedAt,
        Instant createdAt,
        Instant updatedAt
) {}
