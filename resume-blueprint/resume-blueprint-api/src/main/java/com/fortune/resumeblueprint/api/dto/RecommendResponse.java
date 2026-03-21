package com.fortune.resumeblueprint.api.dto;

import java.util.List;

public record RecommendResponse(
        long jdId,
        int total,
        List<CandidateResult> results
) {
    public record CandidateResult(
            String candidateId,
            long documentId,
            double score,
            List<MatchResponse.GapItem> topGaps,
            List<MatchResponse.StrengthItem> topStrengths
    ) {}
}
