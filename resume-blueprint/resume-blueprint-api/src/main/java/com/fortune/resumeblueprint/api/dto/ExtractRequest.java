package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ExtractRequest(
        @NotNull Long documentId,
        @NotBlank String text,
        String docType  // "RESUME" or "JD", optional
) {}
