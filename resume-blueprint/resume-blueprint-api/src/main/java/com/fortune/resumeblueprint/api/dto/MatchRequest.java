package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotNull;

public record MatchRequest(
        @NotNull Long resumeDocumentId,
        String target,  // "internal" | "external" | "both"
        String roleFilter,  // e.g., "Java Backend Engineer"
        String levelFilter  // "junior" | "mid" | "senior"
) {}
