package com.fortune.resumeblueprint.api.dto;

import java.time.Instant;

public record ResumeDocumentResponse(
        long documentId,
        String candidateId,
        String contentHash,
        String contentText,
        Instant createdAt
) {}
