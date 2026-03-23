package com.fortune.resumeblueprint.api.dto;

import java.util.List;

public record AnalyzeResponse(
        long runId,
        String mode,
        String summary,
        List<KeywordItem> keywords,
        List<String> selectedTerms,
        List<KeywordItem> newTerms,
        Integer experienceYears
) {
    public record KeywordItem(
            String term,
            String normalized,
            double score,
            String evidence
    ) {}
}
