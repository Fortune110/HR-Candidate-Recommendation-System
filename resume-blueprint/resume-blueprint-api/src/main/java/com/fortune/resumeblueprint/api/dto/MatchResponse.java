package com.fortune.resumeblueprint.api.dto;

import java.util.List;

public record MatchResponse(
        long matchRunId,
        List<ProfileMatch> matches
) {
    public record ProfileMatch(
            String source,  // "internal_employee" | "external_success"
            double score,
            double overlapScore,
            double gapPenalty,
            double bonusScore,
            List<OverlapItem> topOverlaps,
            List<GapItem> topGaps,
            List<StrengthItem> topStrengths
    ) {}

    public record OverlapItem(String canonical, double weight, String reason) {}

    public record GapItem(String canonical, double weight, String reason) {}

    public record StrengthItem(String canonical, double weight, String reason) {}
}
