package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ChangeStageRequest(
        @NotBlank String toStage,          // enum value as string
        @NotBlank String changedBy,        // operator/user ID
        String note,                       // optional note
        boolean force                      // force update even if in final state
) {}
