package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;

public record JdAnalyzeRequest(
        @NotBlank String text
) {}
