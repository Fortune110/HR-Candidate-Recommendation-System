package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ImportProfileRequest(
        @NotBlank String source,  // "internal_employee" | "external_success"
        @NotBlank String role,
        String level,  // "junior" | "mid" | "senior"
        String company,
        @NotBlank String text  // Profile text
) {}
