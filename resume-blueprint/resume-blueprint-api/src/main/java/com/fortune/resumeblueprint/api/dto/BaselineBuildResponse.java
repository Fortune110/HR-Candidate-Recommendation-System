package com.fortune.resumeblueprint.api.dto;

public record BaselineBuildResponse(
        long baselineSetId,
        int createdTerms
) {}
