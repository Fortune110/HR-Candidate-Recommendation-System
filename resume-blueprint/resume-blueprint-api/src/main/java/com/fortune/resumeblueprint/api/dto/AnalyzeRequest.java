package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;

public record AnalyzeRequest(
        @NotBlank String text
) {}
