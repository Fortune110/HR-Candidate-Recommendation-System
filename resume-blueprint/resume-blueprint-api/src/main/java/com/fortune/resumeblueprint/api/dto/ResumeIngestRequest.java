package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;

public record ResumeIngestRequest(
        @NotBlank String candidateId,
        @NotBlank String text
) {}
