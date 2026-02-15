package com.fortune.resumeblueprint.api.dto;

import jakarta.validation.constraints.NotBlank;

public record ChangeStageRequest(
        @NotBlank String toStage,          // enum value as string
        @NotBlank String changedBy,        // operator/user ID
        String note,                       // optional note
        String reasonCode,                 // optional reason code (e.g., TECH_MISMATCH, SALARY, CANDIDATE_DECLINED, HC_FROZEN, NO_SHOW, OTHER)
        Long jobId,                        // optional job_id for tracking which job/position this relates to
        boolean force                      // force update even if in final state
) {}
