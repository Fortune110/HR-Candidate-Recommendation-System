package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;

public record ResumeDocumentResponse(
        long documentId,
        String entityType,
        String candidateId,
        String contentHash,
        String contentText,
        OffsetDateTime createdAt
) {}
