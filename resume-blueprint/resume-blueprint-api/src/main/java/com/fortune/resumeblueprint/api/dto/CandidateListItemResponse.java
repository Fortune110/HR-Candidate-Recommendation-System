package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;

public record CandidateListItemResponse(
        long documentId,
        String candidateId,
        String entityType,
        OffsetDateTime createdAt,
        Integer experienceYears,
        String seniorityLevel
) {}
