package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;

public record ResumeDocumentResponse(
        long documentId,
        String candidateId,
        String entityType,
        String contentHash,
        String text,
        OffsetDateTime createdAt
) {}
